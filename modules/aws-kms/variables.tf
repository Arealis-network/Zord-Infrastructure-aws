variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "eks_name_prefix" {
  description = "Display name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix for EKS resources."
  type        = string
}
