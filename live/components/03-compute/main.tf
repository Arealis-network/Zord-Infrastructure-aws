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

data "aws_caller_identity" "current" {}
data "aws_ssm_parameter" "ami" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.foundation, region = local.config.aws_region }
}
data "terraform_remote_state" "data" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.data, region = local.config.aws_region }
}

locals {
  admin_principal_arn = try(local.config.cluster.admin_principal_arn, "") != "" ? local.config.cluster.admin_principal_arn : data.aws_caller_identity.current.arn
}

module "compute" {
  source = "../../../stacks/03-compute"

  environment                       = local.config.environment
  aws_region                        = local.config.aws_region
  cluster_name                      = local.config.cluster_name
  eks_name_prefix                   = local.config.eks_name_prefix
  eks_resource_prefix               = local.config.eks_resource_prefix
  node_group_name                   = local.config.node_group_name
  cluster_version                   = local.config.cluster.version
  private_subnet_ids                = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  public_subnet_1_id                = data.terraform_remote_state.foundation.outputs.public_subnet_1_id
  vpc_security_group_id             = data.terraform_remote_state.foundation.outputs.vpc_security_group_id
  rds_security_group_id             = data.terraform_remote_state.data.outputs.rds_security_group_id
  admin_principal_arn               = local.admin_principal_arn
  manage_cluster_admin_access_entry = local.config.cluster.manage_admin_access
  endpoint_public_access            = local.config.cluster.endpoint_public_access
  public_access_cidrs               = local.config.cluster.public_access_cidrs
  ami_id                            = data.aws_ssm_parameter.ami.value
  account_id                        = data.aws_caller_identity.current.account_id
}

output "cluster_name" { value = module.compute.cluster_name }
output "cluster_endpoint" { value = module.compute.cluster_endpoint }
output "cluster_ca_certificate" {
  value     = module.compute.cluster_ca_certificate
  sensitive = true
}
output "cluster_arn" { value = module.compute.cluster_arn }
output "cluster_security_group_id" { value = module.compute.cluster_security_group_id }
output "oidc_provider_arn" { value = module.compute.oidc_provider_arn }
output "oidc_provider_url" { value = module.compute.oidc_provider_url }
output "stateful_node_group_name" { value = module.compute.stateful_node_group_name }
output "stateless_node_group_name" { value = module.compute.stateless_node_group_name }
output "stateful_node_group_id" { value = module.compute.stateful_node_group_id }
output "stateless_node_group_id" { value = module.compute.stateless_node_group_id }
output "worker_role_arn" { value = module.compute.worker_role_arn }
output "pod_identity_addon_id" { value = module.compute.pod_identity_addon_id }
output "bastion_public_ip" { value = module.compute.bastion_public_ip }
output "bastion_instance_id" { value = module.compute.bastion_instance_id }
output "admin_role_arn" { value = module.compute.admin_role_arn }
