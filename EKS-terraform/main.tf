terraform {
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
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

# CloudFront + its WAF are global and require us-east-1 for the WebACL and ACM cert.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ACM lookup matches the certificate's PRIMARY domain name. Our cert's primary
# domain is the apex (zordnet.com) with *.zordnet.com as a SAN, so we query the
# apex — querying "*.zordnet.com" returns "empty result" because that is only a
# subject-alternative-name, not the primary domain.
data "aws_acm_certificate" "wildcard" {
  domain      = var.ses_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

# Auto-discover the Kong ALB by the tag the AWS LB Controller applies.
# IMPORTANT: aws_lbs (plural) returns a LIST and does NOT error when nothing
# matches — unlike aws_lb (singular), which fails the whole apply if the ALB
# is absent. This makes the edge self-healing:
#   - ALB not created yet  -> empty list -> CloudFront skips itself this apply
#   - ALB exists           -> found      -> CloudFront comes up automatically
data "aws_lbs" "kong" {
  count = var.enable_cloudfront_edge && var.kong_alb_domain_name == "" ? 1 : 0

  tags = {
    "ingress.k8s.aws/stack" = var.kong_alb_stack_tag
  }
}

# Resolve the single matching ALB's DNS name (only when exactly one is found).
data "aws_lb" "kong" {
  count = var.enable_cloudfront_edge && var.kong_alb_domain_name == "" && length(try(data.aws_lbs.kong[0].arns, [])) == 1 ? 1 : 0

  arn = tolist(data.aws_lbs.kong[0].arns)[0]
}

locals {
  # Manual override wins; else use the auto-discovered ALB if exactly one exists;
  # else empty (CloudFront stays off this apply).
  kong_alb_dns = (
    var.kong_alb_domain_name != "" ? var.kong_alb_domain_name :
    length(data.aws_lb.kong) == 1 ? data.aws_lb.kong[0].dns_name :
    ""
  )

  # The edge only truly comes up when the ALB origin exists AND the edge is enabled.
  cloudfront_edge_active = var.enable_cloudfront_edge && local.kong_alb_dns != ""
}

# CloudFront only accepts ACM certs from us-east-1. Only looked up when the edge
# is ACTUALLY coming up (ALB origin found) — so a plan on a fresh account with
# no us-east-1 cert yet does NOT fail. The cert must exist by the time Kong's ALB
# exists (see manual.md).
data "aws_acm_certificate" "wildcard_us_east_1" {
  count    = local.cloudfront_edge_active ? 1 : 0
  provider = aws.us_east_1

  domain      = var.ses_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name

  depends_on = [module.eks]
}

locals {
  env_short           = var.environment == "production" ? "prod" : "stg"
  cluster_name        = "arealis-zord-${local.env_short}-eks"
  admin_principal_arn = var.eks_admin_principal_arn != "" ? var.eks_admin_principal_arn : data.aws_caller_identity.current.arn
  vpc_name_prefix     = "Arealis zord ${local.env_short} vpc"
  eks_name_prefix     = "Arealis zord ${local.env_short} eks"
  vpc_resource_prefix = "arealis-zord-${local.env_short}-vpc"
  eks_resource_prefix = "arealis-zord-${local.env_short}-eks"
  node_group_name     = "arealis-zord-${local.env_short}-eks-node-group"
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)

  common_tags = {
    Environment = var.environment
    Project     = "arealis-zord-eks"
    Owner       = "yaswanth"
    ManagedBy   = "Terraform"
    Cluster     = local.cluster_name
  }

  # Use different CIDR ranges per environment so both can coexist in the same account
  # production: 10.0.0.0/16, staging: 10.1.0.0/16
  vpc_cidr      = var.environment == "production" ? "10.0.0.0/16" : "10.1.0.0/16"
  public1_cidr  = var.environment == "production" ? "10.0.1.0/24" : "10.1.1.0/24"
  public2_cidr  = var.environment == "production" ? "10.0.2.0/24" : "10.1.2.0/24"
  private1_cidr = var.environment == "production" ? "10.0.3.0/24" : "10.1.3.0/24"
  private2_cidr = var.environment == "production" ? "10.0.4.0/24" : "10.1.4.0/24"

  # Secret ARNs for External Secrets Operator (all per-service secrets)
  external_secret_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/zord/*"
  ]
}

############################
# VPC MODULE
############################

module "vpc" {
  source = "./modules/aws-vpc"

  environment         = var.environment
  aws_region          = var.aws_region
  vpc_name_prefix     = local.vpc_name_prefix
  vpc_resource_prefix = local.vpc_resource_prefix
  vpc_cidr            = local.vpc_cidr
  public1_cidr        = local.public1_cidr
  public2_cidr        = local.public2_cidr
  private1_cidr       = local.private1_cidr
  private2_cidr       = local.private2_cidr
  availability_zones  = local.availability_zones
}

############################
# EKS CLUSTER MODULE
############################

module "eks" {
  source = "./modules/aws-eks-cluster"

  cluster_name                      = local.cluster_name
  cluster_version                   = var.cluster_version
  private_subnet_ids                = module.vpc.private_subnet_ids
  eks_name_prefix                   = local.eks_name_prefix
  eks_resource_prefix               = local.eks_resource_prefix
  admin_principal_arn               = local.admin_principal_arn
  manage_cluster_admin_access_entry = var.manage_cluster_admin_access_entry
}

############################
# NODE GROUPS MODULE
############################

module "node_groups" {
  source = "./modules/aws-eks-node-groups"

  cluster_name        = module.eks.cluster_name
  cluster_version     = var.cluster_version
  private_subnet_ids  = module.vpc.private_subnet_ids
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
  node_group_name     = local.node_group_name
}

############################
# CORE ADDONS MODULE
############################

module "addons" {
  source = "./modules/aws-eks-addons"

  cluster_name            = module.eks.cluster_name
  stateful_node_group_id  = module.node_groups.stateful_node_group_id
  stateless_node_group_id = module.node_groups.stateless_node_group_id
}

############################
# EBS CSI MODULE
############################

module "ebs_csi" {
  source = "./modules/aws-ebs-csi"

  cluster_name             = module.eks.cluster_name
  eks_name_prefix          = local.eks_name_prefix
  eks_resource_prefix      = local.eks_resource_prefix
  pod_identity_addon_ready = module.addons.pod_identity_addon_id
}

############################
# EC2 ADMIN MODULE
############################

module "ec2_admin" {
  source = "./modules/aws-ec2-admin"

  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
  cluster_name        = module.eks.cluster_name
  public_subnet_id    = module.vpc.public_subnet_1_id
  security_group_id   = module.vpc.security_group_id
  ami_id              = data.aws_ssm_parameter.amazon_linux_2023_ami.value
}

############################
# SES MODULE
############################

module "ses" {
  source = "./modules/aws-ses-email"

  eks_name_prefix              = local.eks_name_prefix
  eks_resource_prefix          = local.eks_resource_prefix
  cluster_name                 = module.eks.cluster_name
  aws_region                   = var.aws_region
  account_id                   = data.aws_caller_identity.current.account_id
  ses_domain                   = var.ses_domain
  ses_workload_namespace       = var.ses_workload_namespace
  ses_workload_service_account = var.ses_workload_service_account
  pod_identity_addon_id        = module.addons.pod_identity_addon_id
}


############################
# KMS MODULE
############################

module "kms" {
  source = "./modules/aws-kms"

  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
}

############################
# S3 BUCKETS MODULE
############################

module "s3_buckets" {
  source = "./modules/aws-s3-buckets"

  environment = var.environment
  kms_key_arn = module.kms.s3_kms_key_arn
}

# Adopt pre-existing S3 buckets (configuration-driven import — HashiCorp's
# recommended, CI-safe, atomic method). import blocks are only allowed in the
# ROOT module. When adopt_existing_buckets=true, Terraform imports the buckets
# that already exist in AWS into state during apply — no BucketAlreadyOwnedByYou,
# no manual deletes. false on a greenfield account -> Terraform just creates them.
locals {
  s3_bucket_ids = {
    edge_ingress               = "zord-edge-ingress"
    intent_canonical           = "zord-intent-engine-canonical"
    intent_nir                 = "zord-intent-engine-nir"
    intent_governance          = "zord-intent-engine-governance"
    outcome_settlement_ingress = "zord-outcome-engine-settlement-ingress"
    evidence_vault             = "zord-evidence-vault"
  }
}

import {
  for_each = var.adopt_existing_buckets ? local.s3_bucket_ids : {}
  to       = module.s3_buckets.aws_s3_bucket.this[each.key]
  id       = each.value
}

############################
# RDS POSTGRES MODULE (free-tier db.t3.micro; scale via variables)
############################
# One RDS instance hosts ALL microservice databases. Private subnets, KMS
# encrypted, ingress locked to the EKS cluster SG. Master password is generated
# by Terraform and published to Secrets Manager (production/zord/db-connection).

module "rds_postgres" {
  source = "./modules/aws-rds-postgres"

  environment               = var.environment
  eks_name_prefix           = local.eks_name_prefix
  eks_resource_prefix       = local.eks_resource_prefix
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = local.vpc_cidr
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_security_group_id = module.eks.cluster_security_group_id
  kms_key_arn               = module.kms.s3_kms_key_arn

  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  multi_az          = var.rds_multi_az
}

############################
# S3 ACCESS MODULE (Pod Identity)
############################

module "s3_access" {
  source = "./modules/aws-s3-access"

  cluster_name        = module.eks.cluster_name
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
  namespace           = "zord"
  kms_key_arn         = module.kms.s3_kms_key_arn

  # Per-service bucket ARNs (PLAT-07 least privilege)
  edge_bucket_arn       = module.s3_buckets.bucket_arns["edge_ingress"]
  canonical_bucket_arn  = module.s3_buckets.bucket_arns["intent_canonical"]
  nir_bucket_arn        = module.s3_buckets.bucket_arns["intent_nir"]
  governance_bucket_arn = module.s3_buckets.bucket_arns["intent_governance"]
  outcome_bucket_arn    = module.s3_buckets.bucket_arns["outcome_settlement_ingress"]
  evidence_bucket_arn   = module.s3_buckets.bucket_arns["evidence_vault"]
  pod_identity_addon_id = module.addons.pod_identity_addon_id
}

############################
# AWS SECRETS MANAGER MODULE
############################

module "secrets_manager" {
  source = "./modules/aws-secrets-manager"

  environment          = var.environment
  s3_kms_key_arn       = module.kms.s3_kms_key_arn
  acm_certificate_arn  = data.aws_acm_certificate.wildcard.arn
  evidence_kms_key_arn = module.kms_evidence_archive.kms_key_arn
}

############################
# TOKEN ENCLAVE KMS MODULE (TOK-03)
############################

module "kms_token_enclave" {
  source = "./modules/aws-kms-token-enclave"

  environment           = var.environment
  account_id            = data.aws_caller_identity.current.account_id
  cluster_name          = module.eks.cluster_name
  eks_name_prefix       = local.eks_name_prefix
  eks_resource_prefix   = local.eks_resource_prefix
  pod_identity_addon_id = module.addons.pod_identity_addon_id
}

############################
# EVIDENCE ARCHIVE KMS MODULE (NEW-P1-06)
############################

module "kms_evidence_archive" {
  source = "./modules/aws-kms-evidence-archive"

  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
  evidence_role_id    = module.s3_access.evidence_role_id
}

############################
# CLUSTER AUTOSCALER MODULE
############################

module "cluster_autoscaler" {
  source = "./modules/helm-cluster-autoscaler"

  cluster_name             = module.eks.cluster_name
  aws_region               = var.aws_region
  eks_name_prefix          = local.eks_name_prefix
  eks_resource_prefix      = local.eks_resource_prefix
  node_groups_ready        = module.node_groups.stateless_node_group_id
  pod_identity_addon_ready = module.addons.pod_identity_addon_id
}

############################
# EXTERNAL SECRETS MODULE
############################

module "external_secrets" {
  source = "./modules/helm-external-secrets"

  cluster_name        = module.eks.cluster_name
  aws_region          = var.aws_region
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix
  namespace           = var.external_secrets_namespace
  service_account     = var.external_secrets_service_account
  secret_arns         = local.external_secret_arns
  node_groups_ready   = module.node_groups.stateless_node_group_id
}

############################
# ARGO ROLLOUTS MODULE
############################

module "argo_rollouts" {
  source = "./modules/helm-argo-rollouts"

  node_groups_ready = module.node_groups.stateless_node_group_id
}

############################
# ARGOCD MODULE
############################

module "argocd" {
  source = "./modules/helm-argocd"

  environment         = var.environment
  domain              = var.ses_domain
  acm_certificate_arn = data.aws_acm_certificate.wildcard.arn
  node_groups_ready   = module.node_groups.stateless_node_group_id
  github_pat          = var.github_pat
}

############################
# CLOUDFRONT + WAF MODULE (MNC edge layer)
############################
# Internet -> CloudFront (WAF/DDoS/cache) -> shared ALB -> Kong -> microservices.
# FULLY AUTOMATIC & SELF-HEALING: Terraform auto-discovers the Kong ALB by tag
# (no manual hostname) and writes the origin-verify secret to Secrets Manager
# (Kong reads it via ESO). If the ALB does not exist yet, the discovery returns
# empty and CloudFront simply skips itself this apply — no failure. Re-running
# apply after Kong is deployed brings the edge up automatically. No manual toggle.

module "cloudfront_waf" {
  source = "./modules/aws-cloudfront-waf"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment         = var.environment
  domain              = var.ses_domain
  subdomain           = var.cloudfront_subdomain
  origin_domain_name  = local.kong_alb_dns
  waf_rate_limit      = var.waf_rate_limit
  acm_certificate_arn = local.cloudfront_edge_active ? data.aws_acm_certificate.wildcard_us_east_1[0].arn : ""
}
