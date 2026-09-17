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

# Allow the cluster role to use the etcd-secrets KMS key (envelope encryption).
resource "aws_iam_role_policy" "cluster_kms" {
  name = "${var.eks_resource_prefix}-cluster-kms"
  role = aws_iam_role.cluster_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
      Resource = aws_kms_key.eks_secrets.arn
    }]
  })
}

# ─────────────────────────────────────────
# KMS key for EKS secrets envelope encryption (etcd) — SEC C3
# ─────────────────────────────────────────

resource "aws_kms_key" "eks_secrets" {
  description             = "${var.eks_name_prefix} EKS etcd secrets envelope encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name = "${var.eks_name_prefix} eks secrets kms"
  }
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.eks_resource_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# NOTE: EKS auto-creates the /aws/eks/<cluster>/cluster CloudWatch log group when
# enabled_cluster_log_types is set. We deliberately DO NOT manage it as a Terraform
# resource — doing so collides on re-apply (EKS may create it first) and the destroy
# workflow already deletes it. This keeps rapid apply→destroy→apply cycles clean.

# ─────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  version  = var.cluster_version

  # SEC C2: full control-plane audit logging (PCI-DSS/SOC2 requirement).
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # SEC C3: envelope-encrypt Kubernetes secrets in etcd with a customer KMS key.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    # SEC C1: public endpoint stays reachable for CI (dynamic-IP runners) but is
    # restrictable. Lock public_access_cidrs to your egress/NAT/office CIDRs in prod.
    endpoint_public_access = var.endpoint_public_access
    public_access_cidrs    = var.public_access_cidrs
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
