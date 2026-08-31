# ═══════════════════════════════════════════════════════════════════
# Cluster Autoscaler — Outputs
# ═══════════════════════════════════════════════════════════════════

output "release_status" {
  description = "Cluster Autoscaler Helm release status."
  value       = helm_release.cluster_autoscaler.status
}

output "role_arn" {
  description = "IAM role ARN used by Cluster Autoscaler."
  value       = aws_iam_role.cluster_autoscaler_role.arn
}
