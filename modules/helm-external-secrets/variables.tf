# ═══════════════════════════════════════════════════════════════════
# External Secrets Operator — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region where Secrets Manager secrets are stored."
  type        = string
}

variable "eks_name_prefix" {
  description = "Name prefix for tags (e.g., 'Arealis zord prod eks')."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix (e.g., 'arealis-zord-prod-eks')."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "service_account" {
  description = "Service account name for External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs that ESO is allowed to read."
  type        = list(string)
}

variable "node_groups_ready" {
  description = "Dependency marker — ensures nodes exist before Helm install."
  type        = any
  default     = null
}
