variable "environment" {
  description = "Deployment environment represented by this composition."
  type        = string
}

variable "aws_region" {
  description = "AWS region in which the composition is deployed."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
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

variable "node_group_name" {
  description = "Base name for EKS managed node groups."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster and node groups."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and node groups."
  type        = list(string)
}

variable "public_subnet_1_id" {
  description = "Public subnet ID in which to place the admin bastion."
  type        = string
}

variable "vpc_security_group_id" {
  description = "Security group ID attached to the admin bastion."
  type        = string
}

variable "rds_security_group_id" {
  description = "Destination RDS security group ID for PostgreSQL ingress from EKS."
  type        = string
}

variable "admin_principal_arn" {
  description = "IAM principal ARN granted EKS cluster administrator access."
  type        = string
}

variable "manage_cluster_admin_access_entry" {
  description = "Whether to manage the EKS cluster administrator access entry."
  type        = bool
}

variable "endpoint_public_access" {
  description = "Whether the EKS API server exposes a public endpoint."
  type        = bool
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint."
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for the EC2 admin bastion."
  type        = string
}

variable "account_id" {
  description = "AWS account ID used to scope admin bastion ECR permissions."
  type        = string
}
