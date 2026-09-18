output "acm_certificate_arn" {
  description = "ACM certificate ARN passed through for downstream ingress configuration."
  value       = var.acm_certificate_arn
}

output "external_secret_arns" {
  description = "Secrets Manager wildcard ARN pattern for External Secrets Operator."
  value       = local.external_secret_arns
}

output "s3_access_role_arns" {
  description = "Map of service names to S3 access IAM role ARNs."
  value       = module.s3_access.role_arns
}

output "evidence_role_id" {
  description = "IAM role ID for the evidence workload."
  value       = module.s3_access.evidence_role_id
}

output "ses_domain" {
  description = "Managed SES domain, or null when domain identity management is disabled."
  value       = try(module.ses_email.ses_domain, null)
}

output "ses_verification_token" {
  description = "SES domain verification token, or null when identity management is disabled."
  value       = try(module.ses_email.ses_verification_token, null)
}

output "ses_dkim_tokens" {
  description = "SES DKIM tokens, or an empty list when identity management is disabled."
  value       = try(module.ses_email.ses_dkim_tokens, [])
}

output "ses_send_role_arn" {
  description = "IAM role ARN used by the SES sending workload."
  value       = module.ses_email.ses_send_role_arn
}

output "token_enclave_role_arn" {
  description = "Token-enclave IAM role ARN passed through for downstream consumers."
  value       = var.token_enclave_role_arn
}

output "resource_group_name" {
  description = "AWS Resource Group containing resources tagged for this project and environment."
  value       = aws_resourcegroups_group.zord.name
}
