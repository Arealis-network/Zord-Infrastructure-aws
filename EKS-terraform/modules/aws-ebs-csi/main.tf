# ═══════════════════════════════════════════════════════════════════
# EBS CSI Driver — Persistent volume provisioning for EKS
# EKS Pod Identity grants EBS permissions (no IMDS needed)
# Self-contained: IAM Role + Pod Identity + EKS Addon
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# IAM Role — EBS CSI (EKS Pod Identity)
# ─────────────────────────────────────────

resource "aws_iam_role" "ebs_csi_role" {
  name = "${var.eks_resource_prefix}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} ebs csi role"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ─────────────────────────────────────────
# EKS Pod Identity Association
# Binds IAM role → ebs-csi-controller-sa service account
# ─────────────────────────────────────────

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_policy,
    var.pod_identity_addon_ready
  ]
}

# ─────────────────────────────────────────
# EBS CSI Driver EKS Addon
# ─────────────────────────────────────────

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_pod_identity_association.ebs_csi
  ]
}

# ─────────────────────────────────────────
# gp3 StorageClass — EKS ships only gp2 by default. Workloads that request
# storageClassName: gp3 (e.g. Prometheus in kube-prometheus-stack) get stuck
# Pending PVCs without this. NOT marked default (EKS gp2 stays the default —
# avoids the "two default StorageClasses" conflict); workloads ask for gp3 by name.
# ─────────────────────────────────────────

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}
