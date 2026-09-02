# ═══════════════════════════════════════════════════════════════════
# AWS S3 Buckets — Zord workload buckets with SSE-KMS encryption
# All buckets use the same customer-managed KMS key
# BucketKeyEnabled reduces KMS API calls (and cost)
# ═══════════════════════════════════════════════════════════════════

locals {
  buckets = {
    edge_ingress               = var.edge_bucket_name
    intent_canonical           = var.canonical_bucket_name
    intent_nir                 = var.nir_bucket_name
    intent_governance          = var.governance_bucket_name
    outcome_settlement_ingress = var.outcome_bucket_name
    evidence_vault             = var.evidence_bucket_name
  }
}

# ─────────────────────────────────────────
# S3 Buckets
# ─────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = each.value
  force_destroy = var.force_destroy_buckets

  tags = {
    Name        = each.value
    Environment = var.environment
    Project     = "arealis-zord"
  }
}

# ─────────────────────────────────────────
# SSE-KMS Encryption (customer-managed key)
# ─────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# ─────────────────────────────────────────
# Block all public access
# ─────────────────────────────────────────

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────
# Versioning (enabled for data protection)
# ─────────────────────────────────────────

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ─────────────────────────────────────────
# TLS-only bucket policy (SEC H5) — deny any request not using HTTPS.
# PCI-DSS/SOC2: data in transit must be encrypted.
# ─────────────────────────────────────────

resource "aws_s3_bucket_policy" "tls_only" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.this[each.key].arn,
        "${aws_s3_bucket.this[each.key].arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
