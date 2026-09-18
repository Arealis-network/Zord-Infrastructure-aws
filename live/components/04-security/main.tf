terraform {
  required_version = ">= 1.11.0"
  backend "s3" {}
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" {
  region = local.config.aws_region
  default_tags { tags = local.common_tags }
}

data "aws_caller_identity" "current" {}
data "aws_acm_certificate" "wildcard" {
  domain      = local.config.dns.ses_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.foundation, region = local.config.aws_region }
}
data "terraform_remote_state" "data" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.data, region = local.config.aws_region }
}
data "terraform_remote_state" "compute" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.compute, region = local.config.aws_region }
}

module "security" {
  source = "../../../stacks/04-security"

  environment                  = local.config.environment
  aws_region                   = local.config.aws_region
  account_id                   = data.aws_caller_identity.current.account_id
  cluster_name                 = local.config.cluster_name
  eks_name_prefix              = local.config.eks_name_prefix
  eks_resource_prefix          = local.config.eks_resource_prefix
  pod_identity_addon_id        = data.terraform_remote_state.compute.outputs.pod_identity_addon_id
  s3_kms_key_arn               = data.terraform_remote_state.foundation.outputs.s3_kms_key_arn
  edge_bucket_arn              = data.terraform_remote_state.data.outputs.s3_bucket_arns["edge_ingress"]
  canonical_bucket_arn         = data.terraform_remote_state.data.outputs.s3_bucket_arns["intent_canonical"]
  nir_bucket_arn               = data.terraform_remote_state.data.outputs.s3_bucket_arns["intent_nir"]
  governance_bucket_arn        = data.terraform_remote_state.data.outputs.s3_bucket_arns["intent_governance"]
  outcome_bucket_arn           = data.terraform_remote_state.data.outputs.s3_bucket_arns["outcome_settlement_ingress"]
  evidence_bucket_arn          = data.terraform_remote_state.data.outputs.s3_bucket_arns["evidence_vault"]
  edge_bucket_name             = data.terraform_remote_state.data.outputs.s3_bucket_names["edge_ingress"]
  canonical_bucket_name        = data.terraform_remote_state.data.outputs.s3_bucket_names["intent_canonical"]
  nir_bucket_name              = data.terraform_remote_state.data.outputs.s3_bucket_names["intent_nir"]
  governance_bucket_name       = data.terraform_remote_state.data.outputs.s3_bucket_names["intent_governance"]
  outcome_bucket_name          = data.terraform_remote_state.data.outputs.s3_bucket_names["outcome_settlement_ingress"]
  evidence_bucket_name         = data.terraform_remote_state.data.outputs.s3_bucket_names["evidence_vault"]
  evidence_kms_key_arn         = data.terraform_remote_state.data.outputs.evidence_kms_key_arn
  token_enclave_kms_key_arn    = data.terraform_remote_state.data.outputs.token_enclave_kms_key_arn
  token_enclave_role_arn       = data.terraform_remote_state.data.outputs.token_enclave_role_arn
  acm_certificate_arn          = data.aws_acm_certificate.wildcard.arn
  ses_domain                   = local.config.dns.ses_domain
  manage_ses_domain_identity   = local.config.ses.manage_domain_identity
  ses_workload_namespace       = local.config.ses.workload_namespace
  ses_workload_service_account = local.config.ses.workload_service_account
}

output "acm_certificate_arn" { value = module.security.acm_certificate_arn }
output "external_secret_arns" { value = module.security.external_secret_arns }
output "s3_access_role_arns" { value = module.security.s3_access_role_arns }
output "ses_domain" { value = module.security.ses_domain }
output "ses_verification_token" { value = module.security.ses_verification_token }
output "ses_dkim_tokens" { value = module.security.ses_dkim_tokens }
output "ses_send_role_arn" { value = module.security.ses_send_role_arn }
output "resource_group_name" { value = module.security.resource_group_name }
