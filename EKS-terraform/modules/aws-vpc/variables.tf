variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "vpc_name_prefix" {
  description = "Name prefix for VPC resources (display names)."
  type        = string
}

variable "vpc_resource_prefix" {
  description = "Resource prefix for VPC resources (resource names)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public1_cidr" {
  description = "CIDR block for public subnet 1."
  type        = string
}

variable "public2_cidr" {
  description = "CIDR block for public subnet 2."
  type        = string
}

variable "private1_cidr" {
  description = "CIDR block for private subnet 1."
  type        = string
}

variable "private2_cidr" {
  description = "CIDR block for private subnet 2."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to use."
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region for VPC endpoint service names."
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the bastion SSH(22)/Jenkins(7777)/SonarQube(7771). Default 0.0.0.0/0 for first bring-up; LOCK to your office/VPN CIDRs for production. Prefer SSM Session Manager over SSH."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch (SEC H4 — network audit trail)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention (days) for VPC Flow Logs."
  type        = number
  default     = 90
}
