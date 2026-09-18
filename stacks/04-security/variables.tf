variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging, or production."
  }
}

variable "aws_region" {
  description = "AWS region containing the security resources."
  type        = string
}

variable "account_id" {
  description = "AWS account ID used to construct resource ARNs."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
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

variable "pod_identity_addon_id" {
  description = "EKS Pod Identity addon ID used as a dependency marker."
  type        = string
}

variable "s3_kms_key_arn" {
  description = "KMS key ARN used for S3 encryption."
  type        = string
}

variable "edge_bucket_arn" {
  description = "ARN of the edge ingress bucket."
  type        = string
}

variable "canonical_bucket_arn" {
  description = "ARN of the intent canonical bucket."
  type        = string
}

variable "nir_bucket_arn" {
  description = "ARN of the intent NIR bucket."
  type        = string
}

variable "governance_bucket_arn" {
  description = "ARN of the intent governance bucket."
  type        = string
}

variable "outcome_bucket_arn" {
  description = "ARN of the outcome settlement ingress bucket."
  type        = string
}

variable "evidence_bucket_arn" {
  description = "ARN of the evidence vault bucket."
  type        = string
}

variable "edge_bucket_name" {
  description = "Name of the edge ingress bucket."
  type        = string
}

variable "canonical_bucket_name" {
  description = "Name of the intent canonical bucket."
  type        = string
}

variable "nir_bucket_name" {
  description = "Name of the intent NIR bucket."
  type        = string
}

variable "governance_bucket_name" {
  description = "Name of the intent governance bucket."
  type        = string
}

variable "outcome_bucket_name" {
  description = "Name of the outcome settlement ingress bucket."
  type        = string
}

variable "evidence_bucket_name" {
  description = "Name of the evidence vault bucket."
  type        = string
}
variable "evidence_kms_key_arn" {
  description = "KMS key ARN for evidence archive encryption."
  type        = string
}

variable "token_enclave_kms_key_arn" {
  description = "KMS key ARN for token-enclave encryption."
  type        = string
}

variable "token_enclave_role_arn" {
  description = "IAM role ARN associated with the token-enclave service account."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN published to shared infrastructure secrets."
  type        = string
}

variable "ses_domain" {
  description = "Domain verified in SES for sending email."
  type        = string
}

variable "manage_ses_domain_identity" {
  description = "Whether this composition owns the account-level SES domain identity."
  type        = bool
  default     = true
}

variable "ses_workload_namespace" {
  description = "Kubernetes namespace of the SES sending workload."
  type        = string
}

variable "ses_workload_service_account" {
  description = "Kubernetes service account of the SES sending workload."
  type        = string
}
