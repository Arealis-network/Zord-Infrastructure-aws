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
# NOTE: pre-existing buckets are adopted via a configuration-driven `import`
# block in the ROOT module (import blocks are only allowed in root), gated by
# var.adopt_existing_buckets. See EKS-terraform/main.tf.
# ─────────────────────────────────────────

# ─────────────────────────────────────────
# S3 Buckets
# ─────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket = each.value

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
