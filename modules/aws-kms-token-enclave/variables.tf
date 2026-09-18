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
  description = "Dependency handle on the EKS Pod Identity addon. Empty when create_pod_identity_association is false."
  type        = any
  default     = null
}

variable "create_pod_identity_association" {
  description = "Whether to create the EKS Pod Identity association. false while the cluster does not exist yet (02-data creates the key+role); true in 04-security once 03-compute has built the cluster."
  type        = bool
  default     = true
}
