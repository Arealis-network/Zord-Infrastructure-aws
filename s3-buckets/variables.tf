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
  description = "Name for S3 bucket 1."
  type        = string
}

variable "bucket_2_name" {
  description = "Name for S3 bucket 2."
  type        = string
}

variable "bucket_3_name" {
  description = "Name for S3 bucket 3."
  type        = string
}

variable "bucket_4_name" {
  description = "Name for S3 bucket 4."
  type        = string
}

variable "bucket_5_name" {
  description = "Name for S3 bucket 5."
  type        = string
}

variable "bucket_6_name" {
  description = "Name for S3 bucket 6."
  type        = string
}
