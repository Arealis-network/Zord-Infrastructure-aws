output "ses_domain" {
  description = "SES domain identity."
  value       = aws_ses_domain_identity.this.domain
}

output "ses_verification_token" {
  description = "TXT record value to add to DNS for SES domain verification."
  value       = aws_ses_domain_identity.this.verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM CNAME tokens to add to DNS. Create CNAME records: <token>._domainkey.<domain> → <token>.dkim.amazonses.com"
  value       = aws_ses_domain_dkim.this.dkim_tokens
}

output "ses_mail_from_domain" {
  description = "MAIL FROM subdomain. Add MX record: mail.<domain> → feedback-smtp.<region>.amazonses.com (priority 10)"
  value       = aws_ses_domain_mail_from.this.mail_from_domain
}

output "ses_send_role_arn" {
  description = "IAM role ARN used by workload pods to send SES emails."
  value       = aws_iam_role.ses_send_role.arn
}

output "ses_sender_emails" {
  description = "Verified sender email addresses."
  value = [
    "support@${var.ses_domain}",
    "no-reply@${var.ses_domain}"
  ]
}
