output "ses_domain" {
  description = "SES domain identity."
  value       = aws_ses_domain_identity.this.domain
}

output "ses_verification_token" {
  description = "TXT record value for SES domain verification."
  value       = aws_ses_domain_identity.this.verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM CNAME tokens for SES."
  value       = aws_ses_domain_dkim.this.dkim_tokens
}

output "ses_send_role_arn" {
  description = "IAM role ARN used by workload pods to send SES emails."
  value       = aws_iam_role.ses_send_role.arn
}
