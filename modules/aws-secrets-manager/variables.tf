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

variable "token_enclave_kms_key_arn" {
  description = "KMS key ARN for the token-enclave CMK (auto-populated from the token-enclave KMS module). Delivered to the token-enclave service via shared-infra so nothing is hardcoded."
  type        = string
}



# ── S3 bucket names (env-scoped) ──
# Passed in from the root module so each environment's services point at THEIR OWN
# buckets. Previously hardcoded, which meant staging/dev would read and write
# production objects. S3 names are globally unique, so prod keeps the unprefixed
# names and non-prod is prefixed (e.g. stg-zord-edge-ingress).
variable "edge_bucket_name" {
  description = "S3 bucket name for zord-edge ingress (EDGE_S3_BUCKET)."
  type        = string
}

variable "canonical_bucket_name" {
  description = "S3 bucket name for intent-engine canonical data (CANNONICALS3_BUCKET)."
  type        = string
}

variable "nir_bucket_name" {
  description = "S3 bucket name for intent-engine NIR data (NIRS3_BUCKET)."
  type        = string
}

variable "governance_bucket_name" {
  description = "S3 bucket name for intent-engine governance data (GOVERNANCES3_BUCKET)."
  type        = string
}

variable "outcome_bucket_name" {
  description = "S3 bucket name for outcome-engine settlement ingress (OUTCOME_S3_BUCKET)."
  type        = string
}

variable "evidence_bucket_name" {
  description = "S3 bucket name for the evidence vault (EVIDENCE_S3_BUCKET)."
  type        = string
}
