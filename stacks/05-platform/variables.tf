variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region containing the EKS cluster and platform resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which the EKS cluster runs."
  type        = string
}

variable "eks_name_prefix" {
  description = "Display-name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource-name prefix for EKS resources."
  type        = string
}

variable "node_groups_ready" {
  description = "Dependency marker indicating that EKS node groups are ready."
  type        = any
}

variable "pod_identity_addon_ready" {
  description = "Dependency marker indicating that the EKS Pod Identity addon is ready."
  type        = any
}

variable "env_domain" {
  description = "Environment domain managed by External DNS and used by Argo CD."
  type        = string
}
variable "acm_certificate_arn" {
  description = "ACM certificate ARN supplied to the Argo CD module."
  type        = string
}

variable "secret_arns" {
  description = "Secrets Manager ARNs that External Secrets Operator may read."
  type        = list(string)
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace for External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account" {
  description = "Kubernetes service account for External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "github_pat" {
  description = "GitHub personal access token used by Argo CD to access the application repository."
  type        = string
  sensitive   = true
}

variable "app_repo_url" {
  description = "Git repository URL containing the applications managed by Argo CD."
  type        = string
}

variable "argocd_alb_group" {
  description = "AWS Load Balancer Controller ingress group used by Argo CD."
  type        = string
}

variable "application_mode" {
  description = "legacy (5 manifest Applications) or helm (15 Helm Applications)."
  type        = string
}

variable "app_target_revision" {
  description = "Git revision ArgoCD watches."
  type        = string
}

variable "values_environment" {
  description = "Directory under kubernetes/values."
  type        = string
}

variable "applications_auto_sync" {
  description = "Enable auto-sync after Jenkins replaces placeholder image tags."
  type        = bool
}

variable "application_name_suffix" {
  description = "Suffix appended to Helm Application names."
  type        = string
}
