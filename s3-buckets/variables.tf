variable "aws_region" {
  description = "AWS region where S3 buckets will be created."
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "production"
}

variable "bucket_1_name" {
  description = "S3 bucket for zord-edge ingress payloads."
  type        = string
  default     = "zord-edge-ingress"
}

variable "bucket_2_name" {
  description = "S3 bucket for zord-intent-engine canonical store."
  type        = string
  default     = "zord-intent-engine-canonical"
}

variable "bucket_3_name" {
  description = "S3 bucket for zord-intent-engine NIR store."
  type        = string
  default     = "zord-intent-engine-nir"
}

variable "bucket_4_name" {
  description = "S3 bucket for zord-intent-engine governance store."
  type        = string
  default     = "zord-intent-engine-governance"
}

variable "bucket_5_name" {
  description = "S3 bucket for zord-outcome-engine settlement ingress."
  type        = string
  default     = "zord-outcome-engine-settlement-ingress"
}

variable "bucket_6_name" {
  description = "S3 bucket for zord-evidence vault."
  type        = string
  default     = "zord-evidence-vault"
}
