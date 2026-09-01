variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB/NLB will be created."
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

variable "chart_version" {
  description = "Pinned aws-load-balancer-controller Helm chart version (free/OSS). Latest stable: 3.5.0."
  type        = string
  default     = "3.5.0"
}

variable "node_groups_ready" {
  description = "Dependency marker — ensures node groups exist before Helm install."
  type        = any
  default     = null
}

variable "pod_identity_addon_ready" {
  description = "Dependency marker — ensures pod identity addon is installed before association."
  type        = any
  default     = null
}
