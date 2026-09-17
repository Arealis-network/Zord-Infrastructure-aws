############################
# environment
############################

variable "environment" {
  description = "Deployment environment. Must be dev, staging or production."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging or production."
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
  description = "Override for the 'ingress.k8s.aws/stack' tag on the ALB fronting Kong, used to auto-discover its DNS name. Leave EMPTY to derive it per environment (production=zord-shared-alb, staging=zord-staging-alb, dev=zord-dev-alb) - set it only to pin a specific ALB, e.g. '<namespace>/<ingress-name>'."
  type        = string
  default     = ""
}

variable "argocd_alb_group" {
  description = "ALB ingress group.name for the ArgoCD UI. Aligned with the app team's convention (zord-observability groups the ops/dashboard hosts). Kong/API hosts use zord-shared-alb."
  type        = string
  default     = "zord-observability"
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

############################
# RDS PostgreSQL (free-tier defaults; change to scale to paid)
############################

variable "rds_instance_class" {
  description = "RDS instance class. db.t3.micro (1GB, ~81 conns) was the free-tier default. Set to db.t3.medium (4GB, ~340 conns) for prod: shared instance runs 8 DBs + monitoring exporters + evidence workers, so it needs real headroom (bigger cache, more CPU credits) to avoid connection starvation + burst throttling under load."
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS storage in GB. Free tier covers 20 GB."
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Multi-AZ standby (HA). NOT free tier — leave false until production paid tier."
  type        = bool
  default     = false
}

############################
# S3 bucket adoption
############################

variable "force_destroy_buckets" {
  description = "When true, destroy empties buckets (deletes all uploaded objects) before deleting them. Set false for production to protect data. Drive via GitHub variable FORCE_DESTROY_BUCKETS."
  type        = bool
  default     = true
}


##########################################################################
# EXPLICIT PER-ENVIRONMENT INPUTS
#
# Set in environments/<env>/terraform.tfvars. Each environment declares its OWN
# values so nothing is silently inherited from a production default - that is
# what previously leaked prod's S3 bucket names, ACM lookup and Kong ALB tag
# into other environments.
#
# All default to "" / null: when empty, main.tf falls back to the built-in
# env maps, so an omitted value still resolves correctly.
##########################################################################

# ── Network ──
variable "vpc_cidr" {
  description = "VPC CIDR for this environment. MUST NOT overlap the other environments (the CIDR guard in the aws-vpc module fails the plan if it does). Empty = derive from the built-in env map."
  type        = string
  default     = ""
}

variable "public1_cidr" {
  description = "Public subnet 1 CIDR. Empty = derive from the built-in env map."
  type        = string
  default     = ""
}

variable "public2_cidr" {
  description = "Public subnet 2 CIDR. Empty = derive from the built-in env map."
  type        = string
  default     = ""
}

variable "private1_cidr" {
  description = "Private subnet 1 CIDR. Empty = derive from the built-in env map."
  type        = string
  default     = ""
}

variable "private2_cidr" {
  description = "Private subnet 2 CIDR. Empty = derive from the built-in env map."
  type        = string
  default     = ""
}

# ── DNS ──
variable "env_domain" {
  description = "DNS zone for THIS environment's ingress hosts (production = zordnet.com, staging = staging.zordnet.com, dev = dev.zordnet.com). Drives External DNS's domain filter and all ingress hostnames. NOTE: ses_domain stays the apex - SES verifies zordnet.com, so SMTP_FROM must not use a subdomain. Empty = derive from the built-in env map."
  type        = string
  default     = ""
}

# ── S3 bucket names ──
# S3 names are GLOBALLY unique, so these must differ per environment. Production
# keeps the original unprefixed names (a bucket cannot be renamed without being
# destroyed, which would delete the evidence vault).
variable "edge_bucket_name" {
  description = "S3 bucket for zord-edge ingress. Empty = derive (prod unprefixed, non-prod env-prefixed)."
  type        = string
  default     = ""
}

variable "canonical_bucket_name" {
  description = "S3 bucket for intent-engine canonical data. Empty = derive."
  type        = string
  default     = ""
}

variable "nir_bucket_name" {
  description = "S3 bucket for intent-engine NIR data. Empty = derive."
  type        = string
  default     = ""
}

variable "governance_bucket_name" {
  description = "S3 bucket for intent-engine governance data. Empty = derive."
  type        = string
  default     = ""
}

variable "outcome_bucket_name" {
  description = "S3 bucket for outcome-engine settlement ingress. Empty = derive."
  type        = string
  default     = ""
}

variable "evidence_bucket_name" {
  description = "S3 bucket for the evidence vault. Empty = derive."
  type        = string
  default     = ""
}

# ── RDS safety ──
variable "rds_deletion_protection" {
  description = "Protect the database from accidental deletion. Set true for a locked-down production; false while the environment is still being torn down and rebuilt (true BLOCKS terraform destroy)."
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Set false for production so a snapshot is always taken before deletion."
  type        = bool
  default     = true
}
