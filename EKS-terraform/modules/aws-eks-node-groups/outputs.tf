# ═══════════════════════════════════════════════════════════════════
# EKS Node Groups — Outputs
# ═══════════════════════════════════════════════════════════════════

output "stateful_node_group_name" {
  description = "Stateful (on-demand) node group name."
  value       = aws_eks_node_group.stateful.node_group_name
}

output "stateless_node_group_name" {
  description = "Stateless (spot) node group name."
  value       = aws_eks_node_group.stateless.node_group_name
}

output "stateful_node_group_id" {
  description = "Stateful node group ID (for depends_on in addons)."
  value       = aws_eks_node_group.stateful.id
}

output "stateless_node_group_id" {
  description = "Stateless node group ID (for depends_on in addons)."
  value       = aws_eks_node_group.stateless.id
}

output "worker_role_arn" {
  description = "IAM role ARN attached to the EKS worker nodes."
  value       = aws_iam_role.worker_role.arn
}
