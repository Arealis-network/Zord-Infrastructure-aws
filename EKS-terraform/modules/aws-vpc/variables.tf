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
