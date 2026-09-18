output "ses_domain" {
  description = "SES domain identity. Returns the configured apex domain even when this environment reuses an identity owned by production."
  value       = var.ses_domain
}

output "ses_verification_token" {
  description = "TXT record value for SES domain verification, or null when this environment does not own the identity."
  value       = var.manage_domain_identity ? aws_ses_domain_identity.this[0].verification_token : null
}

output "ses_dkim_tokens" {
  description = "DKIM CNAME tokens, or an empty list when this environment does not own the identity."
  value       = var.manage_domain_identity ? aws_ses_domain_dkim.this[0].dkim_tokens : []
}

output "ses_send_role_arn" {
  description = "IAM role ARN used by workload pods to send SES emails."
  value       = aws_iam_role.ses_send_role.arn
}
