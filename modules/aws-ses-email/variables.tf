variable "eks_name_prefix" {
  description = "Display name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix for EKS resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "ses_domain" {
  description = "Domain verified in AWS SES."
  type        = string
}

variable "manage_domain_identity" {
  description = "Create/manage the account-level SES apex identity, DKIM and MAIL FROM records. Exactly one environment should own these; other environments create only their own send role and reuse the identity."
  type        = bool
  default     = true
}

variable "ses_workload_namespace" {
  description = "Kubernetes namespace where the workload that sends emails runs."
  type        = string
}

variable "ses_workload_service_account" {
  description = "Kubernetes service account used by the workload that sends emails."
  type        = string
}

variable "pod_identity_addon_id" {
  description = "Pod Identity addon ID (for depends_on)."
  type        = string
}
