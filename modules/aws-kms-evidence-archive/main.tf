# ═══════════════════════════════════════════════════════════════════
# KMS for Evidence Archive (NEW-P1-06) — Per-pack DEK wrapping
# zord-evidence uses this key for envelope encryption of archive packs
# Self-contained: KMS Key + IAM Policy on existing evidence S3 role
# Least privilege: only GenerateDataKey + Decrypt + DescribeKey
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# KMS Key — Evidence archive encryption
# ─────────────────────────────────────────

resource "aws_kms_key" "evidence_archive" {
  description              = "Evidence archive per-pack DEK wrapping (${var.environment})"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 7
  enable_key_rotation      = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "zord-evidence-archive-kms-key-policy"
    Statement = [
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.eks_name_prefix} evidence archive kms key"
    Environment = var.environment
    Service     = "zord-evidence"
  }
}

resource "aws_kms_alias" "evidence_archive" {
  name          = "alias/${var.eks_resource_prefix}-evidence-archive"
  target_key_id = aws_kms_key.evidence_archive.key_id
}

# ─────────────────────────────────────────
# IAM Policy — Attach to existing evidence S3 role
# Only GenerateDataKey + Decrypt + DescribeKey (no Encrypt, no Delete)
# ─────────────────────────────────────────

# Created only when the evidence role is known. In the component layout the KEY
# is created by 02-data (where evidence_role_id is empty) and this POLICY is
# attached by 04-security, which owns the role. Splitting it this way removes the
# circular dependency between the data and security components.
resource "aws_iam_role_policy" "evidence_kms" {
  count = var.evidence_role_id != "" ? 1 : 0

  name = "${var.eks_resource_prefix}-evidence-archive-kms-policy"
  role = var.evidence_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EvidenceArchiveKMS"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.evidence_archive.arn]
      }
    ]
  })
}
