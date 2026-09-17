# ═══════════════════════════════════════════════════════════════════
# External Secrets Operator — Outputs
# ═══════════════════════════════════════════════════════════════════

output "release_status" {
  description = "External Secrets Operator Helm release status."
  value       = helm_release.external_secrets.status
}

output "role_arn" {
  description = "IAM role ARN used by External Secrets Operator."
  value       = aws_iam_role.external_secrets.arn
}

output "namespace" {
  description = "Namespace where External Secrets Operator is deployed."
  value       = helm_release.external_secrets.namespace
}
