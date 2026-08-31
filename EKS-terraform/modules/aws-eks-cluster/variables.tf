# ═══════════════════════════════════════════════════════════════════
# EKS Cluster — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS cluster."
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

variable "admin_principal_arn" {
  description = "IAM principal ARN for EKS cluster admin access."
  type        = string
}

variable "manage_cluster_admin_access_entry" {
  description = "Whether to create and manage the EKS cluster admin access entry."
  type        = bool
}
