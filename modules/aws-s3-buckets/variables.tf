variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for S3 server-side encryption."
  type        = string
}

variable "force_destroy_buckets" {
  description = "When true, `terraform destroy` empties buckets (deletes all uploaded/versioned objects, including versions) before deleting them. Set to true for a full one-click teardown."
  type        = bool
  default     = true
}



# ── Bucket names ──
# S3 bucket names are GLOBALLY unique across all of AWS, so they MUST be
# environment-scoped or a second environment cannot be created at all
# (BucketAlreadyOwnedByYou) and, worse, non-prod services would read/write
# production data. Production keeps its existing unprefixed names for backward
# compatibility; staging/dev get an env prefix. Callers pass these in from the
# root module (see local.bucket_names) — the defaults below are prod's names.
variable "edge_bucket_name" {
  description = "S3 bucket name for zord-edge ingress."
  type        = string
  default     = "zord-edge-ingress"
}

variable "canonical_bucket_name" {
  description = "S3 bucket name for intent engine canonical data."
  type        = string
  default     = "zord-intent-engine-canonical"
}

variable "nir_bucket_name" {
  description = "S3 bucket name for intent engine NIR data."
  type        = string
  default     = "zord-intent-engine-nir"
}

variable "governance_bucket_name" {
  description = "S3 bucket name for intent engine governance data."
  type        = string
  default     = "zord-intent-engine-governance"
}

variable "outcome_bucket_name" {
  description = "S3 bucket name for outcome engine settlement ingress."
  type        = string
  default     = "zord-outcome-engine-settlement-ingress"
}

variable "evidence_bucket_name" {
  description = "S3 bucket name for evidence vault."
  type        = string
  default     = "zord-evidence-vault"
}
