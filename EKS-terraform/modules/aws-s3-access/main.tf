# ═══════════════════════════════════════════════════════════════════
# AWS S3 Access — Per-service IAM Roles (PLAT-07 Least Privilege)
# Each service gets its own role scoped to ONLY its bucket(s)
# A compromised pod cannot access other services' S3 data
# ═══════════════════════════════════════════════════════════════════

locals {
  # Per-service bucket mapping — each service only gets what it needs
  service_buckets = {
    edge = {
      service_account = "zord-edge"
      bucket_arns     = [var.edge_bucket_arn]
    }
    intent = {
      service_account = "zord-intent-engine"
      bucket_arns     = [var.canonical_bucket_arn, var.nir_bucket_arn, var.governance_bucket_arn]
    }
    outcome = {
      service_account = "zord-outcome-engine"
      bucket_arns     = [var.outcome_bucket_arn]
    }
    evidence = {
      service_account = "zord-evidence"
      bucket_arns     = [var.evidence_bucket_arn]
    }
  }
}

# ─────────────────────────────────────────
# IAM Role per service (4 roles total)
# ─────────────────────────────────────────

resource "aws_iam_role" "s3_access" {
  for_each = local.service_buckets

  name = "${var.eks_resource_prefix}-s3-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Name    = "${var.eks_name_prefix} s3 ${each.key} role"
    Service = each.key
  }
}

# ─────────────────────────────────────────
# S3 permissions — each role only accesses its own bucket(s)
# ─────────────────────────────────────────

resource "aws_iam_role_policy" "s3_readwrite" {
  for_each = local.service_buckets

  name = "${var.eks_resource_prefix}-s3-${each.key}-policy"
  role = aws_iam_role.s3_access[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [for arn in each.value.bucket_arns : "${arn}/*"]
      },
      {
        Sid      = "S3ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = each.value.bucket_arns
      }
    ]
  })
}

# ─────────────────────────────────────────
# KMS permissions — all S3 services need encrypt/decrypt
# ─────────────────────────────────────────

resource "aws_iam_role_policy" "kms_access" {
  for_each = local.service_buckets

  name = "${var.eks_resource_prefix}-s3-${each.key}-kms-policy"
  role = aws_iam_role.s3_access[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSEncryptDecrypt"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

# ─────────────────────────────────────────
# EKS Pod Identity — binds each role to its service account
# ─────────────────────────────────────────

resource "aws_eks_pod_identity_association" "s3_access" {
  for_each = local.service_buckets

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = each.value.service_account
  role_arn        = aws_iam_role.s3_access[each.key].arn

  depends_on = [
    aws_iam_role_policy.s3_readwrite,
    aws_iam_role_policy.kms_access,
    var.pod_identity_addon_id
  ]
}
