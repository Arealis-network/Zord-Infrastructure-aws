terraform {
  required_version = ">= 1.11.0"
  backend "s3" {}
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = local.config.aws_region
  default_tags { tags = local.common_tags }
}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.foundation, region = local.config.aws_region }
}

module "data" {
  source = "../../../stacks/02-data"

  environment             = local.config.environment
  cluster_name            = local.config.cluster_name
  eks_name_prefix         = local.config.eks_name_prefix
  eks_resource_prefix     = local.config.eks_resource_prefix
  vpc_id                  = data.terraform_remote_state.foundation.outputs.vpc_id
  private_subnet_ids      = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  private_subnet_cidrs    = data.terraform_remote_state.foundation.outputs.private_subnet_cidrs
  s3_kms_key_arn          = data.terraform_remote_state.foundation.outputs.s3_kms_key_arn
  force_destroy_buckets   = local.config.buckets.force_destroy
  edge_bucket_name        = local.config.buckets.edge
  canonical_bucket_name   = local.config.buckets.canonical
  nir_bucket_name         = local.config.buckets.nir
  governance_bucket_name  = local.config.buckets.governance
  outcome_bucket_name     = local.config.buckets.outcome
  evidence_bucket_name    = local.config.buckets.evidence
  rds_instance_class      = local.config.rds.instance_class
  rds_allocated_storage   = local.config.rds.allocated_storage
  rds_multi_az            = local.config.rds.multi_az
  rds_engine_version      = local.config.rds.engine_version
  rds_deletion_protection = local.config.rds.deletion_protection
  rds_skip_final_snapshot = local.config.rds.skip_final_snapshot
}

output "s3_bucket_names" { value = module.data.s3_bucket_names }
output "s3_bucket_arns" { value = module.data.s3_bucket_arns }
output "rds_endpoint" { value = module.data.rds_endpoint }
output "rds_instance_id" { value = module.data.rds_instance_id }
output "rds_security_group_id" { value = module.data.rds_security_group_id }
output "rds_master_username" { value = module.data.rds_master_username }
output "evidence_kms_key_arn" { value = module.data.evidence_kms_key_arn }
output "evidence_kms_key_id" { value = module.data.evidence_kms_key_id }
output "token_enclave_kms_key_arn" { value = module.data.token_enclave_kms_key_arn }
output "token_enclave_kms_key_id" { value = module.data.token_enclave_kms_key_id }
output "token_enclave_role_arn" { value = module.data.token_enclave_role_arn }
