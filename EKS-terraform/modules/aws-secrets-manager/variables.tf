# ═══════════════════════════════════════════════════════════════════
# AWS Secrets Manager — Variables
# ═══════════════════════════════════════════════════════════════════

variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN for S3 encryption (auto-populated from KMS module)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN (auto-fetched from AWS)."
  type        = string
}

variable "evidence_kms_key_arn" {
  description = "KMS key ARN for evidence archive encryption (NEW-P1-06, auto-populated)."
  type        = string
}
