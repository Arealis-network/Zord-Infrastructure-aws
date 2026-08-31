# ═══════════════════════════════════════════════════════════════════
# EBS CSI Driver — Outputs
# ═══════════════════════════════════════════════════════════════════

output "ebs_csi_addon_id" {
  description = "EBS CSI driver addon ID."
  value       = aws_eks_addon.ebs_csi.id
}

output "role_arn" {
  description = "IAM role ARN used by the EBS CSI driver."
  value       = aws_iam_role.ebs_csi_role.arn
}
