##########################################################################
# Reusable foundation stack: VPC, subnets, NAT, flow logs, base KMS key.
# No backend/provider blocks; a live environment root supplies providers.
##########################################################################

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../modules/aws-vpc"

  environment             = var.environment
  aws_region              = var.aws_region
  cluster_name            = var.cluster_name
  vpc_name_prefix         = var.vpc_name_prefix
  vpc_resource_prefix     = var.vpc_resource_prefix
  vpc_cidr                = var.vpc_cidr
  public1_cidr            = var.public1_cidr
  public2_cidr            = var.public2_cidr
  private1_cidr           = var.private1_cidr
  private2_cidr           = var.private2_cidr
  availability_zones      = var.availability_zones
  admin_cidrs             = var.admin_cidrs
  enable_flow_logs        = var.enable_flow_logs
  flow_log_retention_days = var.flow_log_retention_days
}

module "kms" {
  source = "../../modules/aws-kms"

  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  eks_name_prefix     = var.eks_name_prefix
  eks_resource_prefix = var.eks_resource_prefix
}
