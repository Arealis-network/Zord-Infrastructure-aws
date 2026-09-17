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
# gp3 StorageClass — set as the SINGLE cluster DEFAULT (MNC best practice: gp3 is
# cheaper + faster than gp2). Any PVC with no storageClassName gets gp3, so the
# "unbound immediate PVC" error can't recur. Uses the EBS CSI driver.
# ─────────────────────────────────────────

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
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

# Remove the default flag from EKS's built-in gp2 so there is exactly ONE default
# (gp3). Two default StorageClasses is an error; this unsets gp2's default.
resource "kubernetes_annotations" "gp2_not_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force = true

  depends_on = [kubernetes_storage_class.gp3]
}
