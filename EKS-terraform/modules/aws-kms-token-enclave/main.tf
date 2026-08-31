# ═══════════════════════════════════════════════════════════════════
# KMS for Token Enclave (TOK-03) — Tokenization encryption key
# zord-token-enclave uses this key to encrypt/decrypt PII tokens
# Self-contained: KMS Key + IAM Role + Pod Identity
# No other service can access this key
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# KMS Key — Token Enclave encryption
# ─────────────────────────────────────────

resource "aws_kms_key" "token_enclave" {
  description              = "Arealis Zord token-enclave PII encryption key (${var.environment})"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  deletion_window_in_days  = 30
  enable_key_rotation      = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "zord-token-enclave-kms-key-policy"
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
    Name        = "${var.eks_name_prefix} token enclave kms key"
    Environment = var.environment
    Service     = "zord-token-enclave"
  }
}

resource "aws_kms_alias" "token_enclave" {
  name          = "alias/${var.eks_resource_prefix}-token-enclave"
  target_key_id = aws_kms_key.token_enclave.key_id
}

# ─────────────────────────────────────────
# IAM Role — Token Enclave (EKS Pod Identity)
# Only encrypt/decrypt — cannot manage or delete the key
# ─────────────────────────────────────────

resource "aws_iam_role" "token_enclave" {
  name = "${var.eks_resource_prefix}-token-enclave-kms-role"

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
    Name    = "${var.eks_name_prefix} token enclave kms role"
    Service = "zord-token-enclave"
  }
}

resource "aws_iam_role_policy" "token_enclave_kms" {
  name = "${var.eks_resource_prefix}-token-enclave-kms-policy"
  role = aws_iam_role.token_enclave.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSEncryptDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = [aws_kms_key.token_enclave.arn]
      }
    ]
  })
}

# ─────────────────────────────────────────
# EKS Pod Identity — binds role to zord-token-enclave SA
# ─────────────────────────────────────────

resource "aws_eks_pod_identity_association" "token_enclave" {
  cluster_name    = var.cluster_name
  namespace       = "zord"
  service_account = "zord-token-enclave"
  role_arn        = aws_iam_role.token_enclave.arn

  depends_on = [
    aws_iam_role_policy.token_enclave_kms,
    var.pod_identity_addon_id
  ]
}
