# ═══════════════════════════════════════════════════════════════════
# KMS Evidence Archive — Outputs
# ═══════════════════════════════════════════════════════════════════

output "kms_key_arn" {
  description = "KMS key ARN for evidence archive encryption."
  value       = aws_kms_key.evidence_archive.arn
}

output "kms_key_id" {
  description = "KMS key ID for evidence archive."
  value       = aws_kms_key.evidence_archive.key_id
}
