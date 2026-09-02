variable "eks_name_prefix" {
  description = "Display name prefix for EKS resources."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix for EKS resources."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for the EC2 instance."
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the EC2 instance."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance."
  type        = string
}

variable "account_id" {
  description = "AWS account ID (for scoping ECR repository ARNs)."
  type        = string
}
