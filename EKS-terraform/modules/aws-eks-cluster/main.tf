# ═══════════════════════════════════════════════════════════════════
# EKS Cluster — Control plane + OIDC + Access management
# Self-contained: owns the cluster IAM role it needs to operate
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# IAM Role — Cluster
# ─────────────────────────────────────────

resource "aws_iam_role" "cluster_role" {
  name = "${var.eks_resource_prefix}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} cluster role"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  version  = var.cluster_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  tags = {
    Name = "${var.eks_name_prefix} cluster"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ─────────────────────────────────────────
# OIDC Provider
# ─────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer

  depends_on = [aws_eks_cluster.eks]
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer

  depends_on = [aws_eks_cluster.eks]

  tags = {
    Name = "${var.eks_name_prefix} oidc provider"
  }
}

# ─────────────────────────────────────────
# EKS Access
# ─────────────────────────────────────────

resource "aws_eks_access_entry" "cluster_admin" {
  count = var.manage_cluster_admin_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"

  tags = {
    Name = "${var.eks_name_prefix} cluster admin access entry"
  }
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  count = var.manage_cluster_admin_access_entry ? 1 : 0

  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = var.admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.cluster_admin
  ]
}

data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name

  depends_on = [aws_eks_cluster.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name

  depends_on = [aws_eks_cluster.eks]
}
