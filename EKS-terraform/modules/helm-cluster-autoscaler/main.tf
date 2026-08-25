# ═══════════════════════════════════════════════════════════════════
# Cluster Autoscaler — Scales EKS nodes up/down based on pod demand
# Pod Identity grants ASG permissions (describe, scale, terminate)
# Self-contained: IAM Role + Policy + Pod Identity + Helm
# Chart pinned to v9.43.2 with image v1.32.0 matching EKS version
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# IAM Policy — Cluster Autoscaler
# ─────────────────────────────────────────

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.eks_resource_prefix}-cluster-autoscaler-policy"
  description = "Allows Cluster Autoscaler to manage Auto Scaling Groups"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.eks_name_prefix} cluster autoscaler policy"
  }
}

# ─────────────────────────────────────────
# IAM Role — Cluster Autoscaler (EKS Pod Identity)
# ─────────────────────────────────────────

resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "${var.eks_resource_prefix}-cluster-autoscaler-role"

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
    Name = "${var.eks_name_prefix} cluster autoscaler role"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler_role.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# ─────────────────────────────────────────
# EKS Pod Identity Association
# Binds IAM role → cluster-autoscaler service account
# ─────────────────────────────────────────

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.cluster_autoscaler,
    var.pod_identity_addon_ready
  ]
}

# ─────────────────────────────────────────
# Cluster Autoscaler Helm Release
# ─────────────────────────────────────────

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.43.2"
  namespace  = "kube-system"

  # Pin image to match EKS version (1.32)
  set {
    name  = "image.tag"
    value = "v1.32.0"
  }

  # Cluster discovery — autoscaler finds ASGs tagged with this cluster name
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  # Service account — Pod Identity binds IAM role to this SA automatically
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  # Scaling behavior tuning
  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "2m"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "2m"
  }

  depends_on = [
    aws_eks_pod_identity_association.cluster_autoscaler,
    var.node_groups_ready
  ]
}
