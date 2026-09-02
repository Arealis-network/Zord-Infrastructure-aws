# ═══════════════════════════════════════════════════════════════════
# AWS KMS — Customer-managed key for S3 bucket encryption
# Provides SSE-KMS encryption instead of default SSE-S3 (AES-256)
# ═══════════════════════════════════════════════════════════════════

resource "aws_kms_key" "s3" {
  description              = "Arealis Zord S3 encryption key (${var.environment})"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 7
  enable_key_rotation      = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "zord-s3-kms-key-policy"
    Statement = [
      # Root account full access (required for key management)
      {
        Sid    = "EnableRootAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      # Allow S3 service to use the key for bucket encryption
      {
        Sid    = "AllowS3ServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.eks_name_prefix} s3 kms key"
    Environment = var.environment
    Project     = "arealis-zord"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.eks_resource_prefix}-s3-encryption"
  target_key_id = aws_kms_key.s3.key_id
}
