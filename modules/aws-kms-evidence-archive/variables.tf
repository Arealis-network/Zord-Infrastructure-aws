# ═══════════════════════════════════════════════════════════════════
# KMS Evidence Archive — Variables
# ═══════════════════════════════════════════════════════════════════

variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "eks_name_prefix" {
  description = "Display name prefix for tags."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "evidence_role_id" {
  description = "IAM role ID of the existing evidence S3 access role (to attach KMS policy)."
  type        = string
}
