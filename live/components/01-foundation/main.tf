terraform {
  required_version = ">= 1.11.0"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = local.config.aws_region
  default_tags { tags = local.common_tags }
}

data "aws_availability_zones" "available" { state = "available" }

module "foundation" {
  source = "../../../stacks/01-foundation"

  environment             = local.config.environment
  aws_region              = local.config.aws_region
  cluster_name            = local.config.cluster_name
  vpc_name_prefix         = local.config.vpc_name_prefix
  vpc_resource_prefix     = local.config.vpc_resource_prefix
  eks_name_prefix         = local.config.eks_name_prefix
  eks_resource_prefix     = local.config.eks_resource_prefix
  vpc_cidr                = local.config.network.vpc_cidr
  public1_cidr            = local.config.network.public1_cidr
  public2_cidr            = local.config.network.public2_cidr
  private1_cidr           = local.config.network.private1_cidr
  private2_cidr           = local.config.network.private2_cidr
  availability_zones      = slice(data.aws_availability_zones.available.names, 0, 2)
  admin_cidrs             = local.config.network.admin_cidrs
  enable_flow_logs        = local.config.network.enable_flow_logs
  flow_log_retention_days = local.config.network.flow_log_retention_days
}

output "vpc_id" { value = module.foundation.vpc_id }
output "public_subnet_ids" { value = module.foundation.public_subnet_ids }
output "private_subnet_ids" { value = module.foundation.private_subnet_ids }
output "public_subnet_1_id" { value = module.foundation.public_subnet_1_id }
output "vpc_security_group_id" { value = module.foundation.vpc_security_group_id }
output "private_subnet_cidrs" { value = [local.config.network.private1_cidr, local.config.network.private2_cidr] }
output "s3_kms_key_arn" { value = module.foundation.s3_kms_key_arn }
output "s3_kms_key_id" { value = module.foundation.s3_kms_key_id }
output "cluster_name" { value = local.config.cluster_name }
output "env_domain" { value = local.config.dns.env_domain }
