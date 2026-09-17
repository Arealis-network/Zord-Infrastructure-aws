# ═══════════════════════════════════════════════════════════════════
# EKS Core Addons — Networking + DNS + Pod Identity agent
# These are cluster-level infrastructure addons with no custom IAM
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# VPC CNI (with Network Policy support)
# ─────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}

# ─────────────────────────────────────────
# CoreDNS
# ─────────────────────────────────────────

resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name   = "coredns"

  resolve_conflicts_on_update = "OVERWRITE"
}

# ─────────────────────────────────────────
# kube-proxy
# ─────────────────────────────────────────

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_update = "OVERWRITE"
}

# ─────────────────────────────────────────
# Pod Identity Agent
# ─────────────────────────────────────────

resource "aws_eks_addon" "pod_identity" {
  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_update = "OVERWRITE"
}
