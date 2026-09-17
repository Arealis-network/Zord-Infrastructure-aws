# ═══════════════════════════════════════════════════════════════════
# Cluster Autoscaler — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name for autoscaler ASG discovery."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
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

variable "node_groups_ready" {
  description = "Dependency marker — ensures node groups exist before Helm install."
  type        = any
  default     = null
}

variable "pod_identity_addon_ready" {
  description = "Dependency marker — ensures pod identity addon is installed before association."
  type        = any
  default     = null
}
