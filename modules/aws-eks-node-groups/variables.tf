# ═══════════════════════════════════════════════════════════════════
# EKS Node Groups — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the node groups."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for node groups."
  type        = list(string)
}

variable "eks_name_prefix" {
  description = "Display name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix for EKS resources."
  type        = string
}

variable "node_group_name" {
  description = "Base name for node groups."
  type        = string
}
