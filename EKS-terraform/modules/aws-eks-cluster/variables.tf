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

variable "endpoint_public_access" {
  description = "Whether the EKS API server has a public endpoint. Keep true so dynamic-IP CI runners can reach it; set false for fully-private clusters with a self-hosted runner."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Default 0.0.0.0/0 (open). Lock to your egress/NAT/office CIDRs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "control_plane_log_retention_days" {
  description = "CloudWatch retention (days) for EKS control-plane audit logs."
  type        = number
  default     = 90
}
