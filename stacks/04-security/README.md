# 04 Security composition

Reusable Terraform composition for the Arealis Zord security tier. It contains no backend or provider configuration; the calling root module supplies those concerns.

## Resources

- Per-workload S3 IAM roles and EKS Pod Identity associations via `../../modules/aws-s3-access`.
- Service secrets via `../../modules/aws-secrets-manager`.
- SES identity, send role, and Pod Identity via `../../modules/aws-ses-email`.
- An evidence-role inline policy granting `GenerateDataKey`, `Decrypt`, and `DescribeKey` on the evidence archive KMS key.
- A token-enclave Pod Identity association for `zord/zord-token-enclave`.
- An AWS Resource Group filtered to `Project=arealis-zord-eks` and the selected environment.

## Usage

```hcl
module "security" {
  source = "../../../stacks/04-security"

  environment         = var.environment
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  cluster_name        = data.terraform_remote_state.compute.outputs.cluster_name
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix

  pod_identity_addon_id = data.terraform_remote_state.compute.outputs.pod_identity_addon_id
  s3_kms_key_arn         = data.terraform_remote_state.foundation.outputs.s3_kms_key_arn

  edge_bucket_arn       = data.terraform_remote_state.data.outputs.bucket_arns["edge_ingress"]
  canonical_bucket_arn  = data.terraform_remote_state.data.outputs.bucket_arns["intent_canonical"]
  nir_bucket_arn        = data.terraform_remote_state.data.outputs.bucket_arns["intent_nir"]
  governance_bucket_arn = data.terraform_remote_state.data.outputs.bucket_arns["intent_governance"]
  outcome_bucket_arn    = data.terraform_remote_state.data.outputs.bucket_arns["outcome_settlement_ingress"]
  evidence_bucket_arn   = data.terraform_remote_state.data.outputs.bucket_arns["evidence_vault"]

  edge_bucket_name       = data.terraform_remote_state.data.outputs.bucket_names["edge_ingress"]
  canonical_bucket_name  = data.terraform_remote_state.data.outputs.bucket_names["intent_canonical"]
  nir_bucket_name        = data.terraform_remote_state.data.outputs.bucket_names["intent_nir"]
  governance_bucket_name = data.terraform_remote_state.data.outputs.bucket_names["intent_governance"]
  outcome_bucket_name    = data.terraform_remote_state.data.outputs.bucket_names["outcome_settlement_ingress"]
  evidence_bucket_name   = data.terraform_remote_state.data.outputs.bucket_names["evidence_vault"]

  evidence_kms_key_arn      = data.terraform_remote_state.data.outputs.evidence_kms_key_arn
  token_enclave_kms_key_arn = data.terraform_remote_state.data.outputs.token_enclave_kms_key_arn
  token_enclave_role_arn    = data.terraform_remote_state.data.outputs.token_enclave_role_arn
  acm_certificate_arn       = data.terraform_remote_state.foundation.outputs.acm_certificate_arn

  ses_domain                   = var.ses_domain
  manage_ses_domain_identity   = var.manage_ses_domain_identity
  ses_workload_namespace       = var.ses_workload_namespace
  ses_workload_service_account = var.ses_workload_service_account
}
```

Exactly one environment should set `manage_ses_domain_identity = true`; other environments can reuse the account-level identity while creating their own send role and Pod Identity association.

## Outputs

The composition exposes the ACM certificate ARN, External Secrets wildcard ARN, S3 role ARN map, evidence role ID, safe SES values, SES send role ARN, token-enclave role ARN, and resource-group name.

> The current `aws-ses-email` child module uses `count` on its identity resources but references them without indexes in its outputs. This composition wraps those outputs with `try(...)`; the child outputs should still be corrected separately to use indexed/splat references.