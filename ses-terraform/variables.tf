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

variable "aws_region" {
  description = "AWS region for SES and IAM resources."
  type        = string
  default     = "ap-south-1"
}

############################
# SES settings
############################

variable "ses_domain" {
  description = "Domain to verify in AWS SES for sending OTP emails."
  type        = string
  default     = "zordnet.com"
}

############################
# EKS pod identity settings
############################

variable "eks_cluster_name" {
  description = "EKS cluster name to associate the SES send role with. Defaults to arealis-zord-<env>-eks based on environment."
  type        = string
  default     = ""
}

variable "workload_namespace" {
  description = "Kubernetes namespace where the workload that sends emails runs."
  type        = string
  default     = "zord"
}

variable "workload_service_account" {
  description = "Kubernetes service account used by the workload that sends emails."
  type        = string
  default     = "zord-app"
}
