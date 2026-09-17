# ═══════════════════════════════════════════════════════════════════
# KMS Token Enclave — Outputs
# ═══════════════════════════════════════════════════════════════════

output "kms_key_arn" {
  description = "KMS key ARN for token-enclave PII encryption."
  value       = aws_kms_key.token_enclave.arn
}

output "kms_key_id" {
  description = "KMS key ID for token-enclave."
  value       = aws_kms_key.token_enclave.key_id
}

output "role_arn" {
  description = "IAM role ARN for zord-token-enclave KMS access."
  value       = aws_iam_role.token_enclave.arn
}
