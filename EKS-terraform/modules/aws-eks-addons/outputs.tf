# ═══════════════════════════════════════════════════════════════════
# EKS Core Addons — Outputs
# ═══════════════════════════════════════════════════════════════════

output "vpc_cni_addon_id" {
  description = "VPC CNI addon ID."
  value       = aws_eks_addon.vpc_cni.id
}

output "coredns_addon_id" {
  description = "CoreDNS addon ID."
  value       = aws_eks_addon.coredns.id
}

output "kube_proxy_addon_id" {
  description = "kube-proxy addon ID."
  value       = aws_eks_addon.kube_proxy.id
}

output "pod_identity_addon_id" {
  description = "Pod Identity agent addon ID."
  value       = aws_eks_addon.pod_identity.id
}
