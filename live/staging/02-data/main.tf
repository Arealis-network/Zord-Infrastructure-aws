##########################################################################
# 02-DATA — persistent stores
#
# Depends on: 01-foundation (VPC, subnets, KMS)
# Owns: RDS Postgres, S3 buckets, and the KMS keys for evidence archive and
#       the token enclave.
#
# Separate state because this is the ONLY component holding stateful data. A
# platform or edge change can never plan a database or bucket replacement.
##########################################################################

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

# ── Upstream component ──
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = local.state_keys.foundation
    region = var.aws_region
  }
}

locals {
  foundation = data.terraform_remote_state.foundation.outputs
}

# ── S3 buckets ──
# Names come from local.bucket_names: production keeps the original unprefixed
# names, non-prod is env-prefixed so it can never touch production objects.
module "s3_buckets" {
  source = "../../../modules/aws-s3-buckets"

  environment           = var.environment
  kms_key_arn           = local.foundation.s3_kms_key_arn
  force_destroy_buckets = var.force_destroy_buckets

  edge_bucket_name       = local.bucket_names.edge
  canonical_bucket_name  = local.bucket_names.canonical
  nir_bucket_name        = local.bucket_names.nir
  governance_bucket_name = local.bucket_names.governance
  outcome_bucket_name    = local.bucket_names.outcome
  evidence_bucket_name   = local.bucket_names.evidence
}

# ── KMS: evidence archive (per-pack DEK wrapping) ──
module "kms_evidence_archive" {
  source = "../../../modules/aws-kms-evidence-archive"

  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
  # The IAM policy is attached in 04-security, which owns the evidence role.
  evidence_role_id = ""
}

# ── KMS: token enclave ──
module "kms_token_enclave" {
  source = "../../../modules/aws-kms-token-enclave"

  environment           = var.environment
  account_id            = data.aws_caller_identity.current.account_id
  cluster_name          = local.cluster_name
  eks_name_prefix       = local.eks_name_prefix
  eks_resource_prefix   = local.eks_resource_prefix
  pod_identity_addon_id = "" # association is created in 04-security
}

# ── RDS Postgres ──
# One instance per environment hosting all 8 service databases (created by the
# app team's bootstrap Job). Private subnets only, TLS enforced, KMS encrypted.
module "rds_postgres" {
  source = "../../../modules/aws-rds-postgres"

  environment          = var.environment
  eks_name_prefix      = local.eks_name_prefix
  eks_resource_prefix  = local.eks_resource_prefix
  vpc_id               = local.foundation.vpc_id
  private_subnet_ids   = local.foundation.private_subnet_ids
  private_subnet_cidrs = local.foundation.private_subnet_cidrs
  kms_key_arn          = local.foundation.s3_kms_key_arn

  # The cluster SG does not exist until 03-compute. Ingress from the private
  # subnet CIDRs above already covers pods/nodes, so this is left empty and the
  # cluster-SG rule is added by 03-compute.
  cluster_security_group_id = ""

  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  multi_az          = var.rds_multi_az
  engine_version    = var.rds_engine_version

  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
}
