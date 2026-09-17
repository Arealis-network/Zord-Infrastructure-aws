# ═══════════════════════════════════════════════════════════════════
# EBS CSI Driver — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "eks_name_prefix" {
  description = "Display name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix for EKS resources."
  type        = string
}

variable "pod_identity_addon_ready" {
  description = "Dependency marker — ensures pod identity addon is installed before association."
  type        = any
  default     = null
}
