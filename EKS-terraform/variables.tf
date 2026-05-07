############################
# cluster settings
############################

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster and node group."
  type        = string
  default     = "1.35"
}

variable "aws_region" {
  description = "AWS region where the EKS infrastructure will be created."
  type        = string
  default     = "ap-south-1"
}

variable "eks_admin_principal_arn" {
  description = "IAM principal ARN that should receive EKS cluster admin access. Leave empty to use the currently authenticated AWS principal."
  type        = string
  default     = ""
}

variable "manage_cluster_admin_access_entry" {
  description = "Set to true only if you want Terraform to create and manage the EKS cluster admin access entry."
  type        = bool
  default     = false
}

############################
# external secrets settings
############################

variable "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator will run."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account" {
  description = "Service account name used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "app_secret_name" {
  description = "AWS Secrets Manager app secret name consumed by External Secrets Operator."
  type        = string
  default     = "zord/app-secrets"
}

variable "edge_signing_key_secret_name" {
  description = "AWS Secrets Manager edge signing key secret name consumed by External Secrets Operator."
  type        = string
  default     = "zord/edge-signing-key"
}
