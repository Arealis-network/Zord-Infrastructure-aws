# ═══════════════════════════════════════════════════════════════════
# AWS S3 Access — Variables
# ═══════════════════════════════════════════════════════════════════

variable "eks_name_prefix" {
  description = "Display name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix for EKS resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where S3 workloads run."
  type        = string
  default     = "zord"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption."
  type        = string
}

# ── Per-service bucket ARNs ──

variable "edge_bucket_arn" {
  description = "ARN of the zord-edge-ingress S3 bucket."
  type        = string
}

variable "canonical_bucket_arn" {
  description = "ARN of the zord-intent-engine-canonical S3 bucket."
  type        = string
}

variable "nir_bucket_arn" {
  description = "ARN of the zord-intent-engine-nir S3 bucket."
  type        = string
}

variable "governance_bucket_arn" {
  description = "ARN of the zord-intent-engine-governance S3 bucket."
  type        = string
}

variable "outcome_bucket_arn" {
  description = "ARN of the zord-outcome-engine-settlement-ingress S3 bucket."
  type        = string
}

variable "evidence_bucket_arn" {
  description = "ARN of the zord-evidence-vault S3 bucket."
  type        = string
}

variable "pod_identity_addon_id" {
  description = "Pod Identity addon ID (for depends_on)."
  type        = string
}
