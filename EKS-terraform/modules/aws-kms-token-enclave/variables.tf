# ═══════════════════════════════════════════════════════════════════
# KMS Token Enclave — Variables
# ═══════════════════════════════════════════════════════════════════

variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
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

variable "pod_identity_addon_id" {
  description = "Pod Identity addon ID (for depends_on)."
  type        = string
}
