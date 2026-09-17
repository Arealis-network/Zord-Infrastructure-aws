##########################################################################
# 01-FOUNDATION — network + encryption keys
#
# First component applied. Has NO dependency on any other component.
# Owns: VPC, subnets, NAT, route tables, flow logs, and the KMS keys that
# later components (S3, RDS, evidence, token-enclave) encrypt with.
#
# Changes here are rare. Keeping it in its own state means a routine platform
# or Helm change can never plan a VPC replacement.
##########################################################################

terraform {
  required_version = ">= 1.11.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ── Network ──
module "vpc" {
  source = "../../../modules/aws-vpc"

  environment             = var.environment
  aws_region              = var.aws_region
  cluster_name            = local.cluster_name # used by the CIDR conflict guard
  vpc_name_prefix         = local.vpc_name_prefix
  vpc_resource_prefix     = local.vpc_resource_prefix
  vpc_cidr                = local.vpc_cidr
  public1_cidr            = local.public1_cidr
  public2_cidr            = local.public2_cidr
  private1_cidr           = local.private1_cidr
  private2_cidr           = local.private2_cidr
  availability_zones      = local.availability_zones
  admin_cidrs             = var.admin_cidrs
  enable_flow_logs        = var.enable_flow_logs
  flow_log_retention_days = var.flow_log_retention_days
}

# ── Encryption keys ──
# Created here (not in 02-data) so the data tier and the platform tier can both
# reference them without a circular dependency.
module "kms" {
  source = "../../../modules/aws-kms"

  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
}

data "aws_caller_identity" "current" {}
