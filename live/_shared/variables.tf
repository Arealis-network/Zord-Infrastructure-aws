##########################################################################
# SHARED VARIABLE CONTRACT
#
# Every component root declares the same variables so a single
# live/<env>/terraform.tfvars can drive all of them. Components ignore the
# variables they do not need.
#
# This file is the source of truth - it is copied into each component
# directory as variables.tf. Do not edit the copies.
##########################################################################

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging or production."
  }
}

variable "aws_region" {
  description = "AWS region for all regional resources."
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket" {
  description = "S3 bucket holding Terraform state. Used to read other components' outputs via terraform_remote_state. Supplied by the pipeline."
  type        = string
  default     = ""
}

# ── Network ──
variable "vpc_cidr" {
  description = "VPC CIDR. MUST NOT overlap the other environments; the CIDR guard fails the plan if it does."
  type        = string
  default     = ""
}

variable "public1_cidr" {
  description = "Public subnet 1 CIDR."
  type        = string
  default     = ""
}

variable "public2_cidr" {
  description = "Public subnet 2 CIDR."
  type        = string
  default     = ""
}

variable "private1_cidr" {
  description = "Private subnet 1 CIDR."
  type        = string
  default     = ""
}

variable "private2_cidr" {
  description = "Private subnet 2 CIDR."
  type        = string
  default     = ""
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the bastion over SSH. Never 0.0.0.0/0."
  type        = list(string)
  default     = []
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs (required for the security baseline)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention for VPC flow logs."
  type        = number
  default     = 30
}

# ── DNS ──
variable "env_domain" {
  description = "DNS zone for THIS environment's ingress hosts (production = zordnet.com, staging = staging.zordnet.com, dev = dev.zordnet.com)."
  type        = string
  default     = ""
}

variable "ses_domain" {
  description = "SES email domain. ALWAYS the apex - SES verifies zordnet.com, so SMTP_FROM must not use a subdomain."
  type        = string
  default     = "zordnet.com"
}

# ── Ingress / edge ──
variable "kong_alb_stack_tag" {
  description = "Value of the 'ingress.k8s.aws/stack' tag on the ALB fronting Kong, used to auto-discover its DNS name. MUST be environment-specific or a non-prod apply discovers production's ALB."
  type        = string
  default     = ""
}

variable "argocd_alb_group" {
  description = "ALB ingress group.name for the ArgoCD UI."
  type        = string
  default     = ""
}

variable "enable_cloudfront_edge" {
  description = "Enable the CloudFront + WAF edge. Self-healing: if Kong's ALB does not exist yet the edge skips itself and comes up on a later apply."
  type        = bool
  default     = true
}

variable "cloudfront_subdomain" {
  description = "Subdomain CloudFront serves (e.g. 'api')."
  type        = string
  default     = "api"
}

variable "kong_alb_domain_name" {
  description = "Manual override for the Kong ALB DNS name. Empty = auto-discover by tag."
  type        = string
  default     = ""
}

variable "waf_rate_limit" {
  description = "WAF rate-limit rule threshold (requests per 5 minutes per IP)."
  type        = number
  default     = 2000
}

# ── S3 buckets (globally unique, so environment-specific) ──
variable "edge_bucket_name" {
  description = "S3 bucket for zord-edge ingress."
  type        = string
  default     = ""
}

variable "canonical_bucket_name" {
  description = "S3 bucket for intent-engine canonical data."
  type        = string
  default     = ""
}

variable "nir_bucket_name" {
  description = "S3 bucket for intent-engine NIR data."
  type        = string
  default     = ""
}

variable "governance_bucket_name" {
  description = "S3 bucket for intent-engine governance data."
  type        = string
  default     = ""
}

variable "outcome_bucket_name" {
  description = "S3 bucket for outcome-engine settlement ingress."
  type        = string
  default     = ""
}

variable "evidence_bucket_name" {
  description = "S3 bucket for the evidence vault."
  type        = string
  default     = ""
}

variable "force_destroy_buckets" {
  description = "When true, destroy empties buckets first. MUST be false for production - the evidence vault holds audit artefacts."
  type        = bool
  default     = true
}

# ── Data tier ──
variable "rds_instance_class" {
  description = "RDS instance class. db.t3.micro gives only ~81 connections; use small (~160) or medium (~340)."
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS storage in GB."
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Multi-AZ standby for automatic failover. Doubles RDS cost."
  type        = bool
  default     = false
}

variable "rds_engine_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "rds_deletion_protection" {
  description = "Protect the database from deletion. true BLOCKS terraform destroy."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Set false for production."
  type        = bool
  default     = true
}

# ── Compute ──
variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.32"
}

variable "eks_admin_principal_arn" {
  description = "IAM principal granted cluster-admin. Empty = the caller identity."
  type        = string
  default     = ""
}

variable "manage_cluster_admin_access_entry" {
  description = "Whether Terraform manages the cluster admin access entry."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server is reachable from the internet."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── Platform ──
variable "app_repo_url" {
  description = "Git repository ArgoCD syncs application manifests from."
  type        = string
  default     = "https://github.com/Arealis-network/Arealis-Zord-intent.git"
}

variable "github_pat" {
  description = "GitHub PAT for ArgoCD's private-repo secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_secrets_namespace" {
  description = "Namespace for the External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account" {
  description = "Service account for the External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "ses_workload_namespace" {
  description = "Namespace of the workload that sends email via SES."
  type        = string
  default     = "zord"
}

variable "ses_workload_service_account" {
  description = "Service account of the workload that sends email via SES."
  type        = string
  default     = "zord-app"
}
