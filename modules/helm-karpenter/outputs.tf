# ═══════════════════════════════════════════════════════════════════
# Karpenter — Outputs
# ═══════════════════════════════════════════════════════════════════

output "release_status" {
  description = "Karpenter Helm release status."
  value       = helm_release.karpenter.status
}

output "controller_role_arn" {
  description = "IAM role ARN used by the Karpenter controller."
  value       = aws_iam_role.karpenter_controller.arn
}

output "node_instance_profile" {
  description = "Instance profile Karpenter-launched nodes use."
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "interruption_queue" {
  description = "SQS queue Karpenter watches for spot/interruption events."
  value       = aws_sqs_queue.karpenter_interruption.name
}
