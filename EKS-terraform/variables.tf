############################
# environment
############################

variable "environment" {
  description = "Deployment environment. Must be staging or production."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

############################
# cluster settings
############################

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster and node group."
  type        = string
  default     = "1.32"
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

variable "evidence_signing_key_secret_name" {
  description = "AWS Secrets Manager evidence signing key secret name consumed by External Secrets Operator."
  type        = string
  default     = "zord/evidence-signing-key"
}

############################
# SES email settings
############################

variable "ses_domain" {
  description = "Domain verified in AWS SES for sending OTP emails."
  type        = string
  default     = "zordnet.com"
}

variable "ses_workload_namespace" {
  description = "Kubernetes namespace where the workload that sends emails runs."
  type        = string
  default     = "zord"
}

variable "ses_workload_service_account" {
  description = "Kubernetes service account used by the workload that sends emails."
  type        = string
  default     = "zord-app"
}

############################
# ArgoCD settings
############################

variable "github_pat" {
  description = "GitHub Personal Access Token for ArgoCD repo access. Pass via TF_VAR_github_pat or -var."
  type        = string
  sensitive   = true
  default     = ""
}

############################
# CloudFront + WAF (edge layer)
############################

variable "cloudfront_subdomain" {
  description = "Subdomain fronted by CloudFront (e.g. api => api.zordnet.com)."
  type        = string
  default     = "api"
}

variable "kong_alb_domain_name" {
  description = "Manual override for the shared ALB DNS name that fronts Kong. Normally leave EMPTY — Terraform auto-discovers the ALB by tag (see kong_alb_stack_tag). Only set this if auto-discovery does not fit your setup."
  type        = string
  default     = ""
}

variable "kong_alb_stack_tag" {
  description = "Value of the 'ingress.k8s.aws/stack' tag the AWS LB Controller puts on the shared ALB fronting Kong. Terraform uses this to auto-discover the ALB DNS name — no manual copy needed. For a shared ALB group this is the group name (e.g. 'zord-shared-alb'); for a standalone ingress it is '<namespace>/<ingress-name>' (e.g. 'api-gateway/kong-public')."
  type        = string
  default     = "zord-shared-alb"
}

variable "enable_cloudfront_edge" {
  description = "Master switch for the CloudFront/WAF edge layer. When true (default), Terraform auto-discovers the Kong ALB and brings up CloudFront + WAF. Safe to leave on: if the ALB does not exist yet, the edge self-skips this apply and comes up automatically on a later apply once Kong is deployed. Set false to hard-disable the edge entirely."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Max requests per IP in a 5-minute window before WAF blocks (DDoS mitigation)."
  type        = number
  default     = 2000
}
