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
  description = "IAM role (name/id) of the evidence workload that the KMS policy is attached to. Empty while the role does not exist yet (02-data creates only the key); 04-security supplies it and the policy is then attached."
  type        = string
  default     = ""
}
