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
  }
}

provider "aws" {
  region = var.aws_region

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

data "aws_acm_certificate" "wildcard" {
  domain      = "*.${var.ses_domain}"
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

  # Secret ARNs for External Secrets Operator
  external_secret_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/${var.app_secret_name}*",
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/${var.edge_signing_key_secret_name}*",
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/${var.evidence_signing_key_secret_name}*"
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

  environment         = var.environment
  s3_kms_key_arn      = module.kms.s3_kms_key_arn
  acm_certificate_arn = data.aws_acm_certificate.wildcard.arn
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
