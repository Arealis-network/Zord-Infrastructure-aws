# ═══════════════════════════════════════════════════════════════════
# AWS Secrets Manager — Outputs
# ═══════════════════════════════════════════════════════════════════

output "app_secret_name" {
  description = "Full name of the application secret."
  value       = aws_secretsmanager_secret.app_secrets.name
}

output "app_secret_arn" {
  description = "ARN of the application secret."
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "edge_signing_key_secret_name" {
  description = "Full name of the edge signing key secret."
  value       = aws_secretsmanager_secret.edge_signing_key.name
}

output "edge_signing_key_secret_arn" {
  description = "ARN of the edge signing key secret."
  value       = aws_secretsmanager_secret.edge_signing_key.arn
}

output "evidence_signing_key_secret_name" {
  description = "Full name of the evidence signing key secret."
  value       = aws_secretsmanager_secret.evidence_signing_key.name
}

output "evidence_signing_key_secret_arn" {
  description = "ARN of the evidence signing key secret."
  value       = aws_secretsmanager_secret.evidence_signing_key.arn
}
