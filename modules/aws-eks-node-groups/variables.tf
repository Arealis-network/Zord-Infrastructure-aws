# ═══════════════════════════════════════════════════════════════════
# EKS Node Groups — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the node groups."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for node groups."
  type        = list(string)
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
  description = "Base name for node groups."
  type        = string
}

# ── Elasticity: per-env node group sizing + instance types ──
# Defaults preserve the original behavior; override per env in config.json to
# right-size for cost (e.g. smaller desired counts / min=0 for scale-to-zero).

variable "stateful_instance_types" {
  description = "Instance types for the stateful (on-demand) node group."
  type        = list(string)
  default     = ["t3.xlarge"]
}
variable "stateful_min_size" {
  type    = number
  default = 1
}
variable "stateful_desired_size" {
  type    = number
  default = 1
}
variable "stateful_max_size" {
  type    = number
  default = 3
}

variable "stateless_instance_types" {
  description = "Instance types for the stateless (spot) node group."
  type        = list(string)
  default     = ["t3.large", "t3.xlarge", "m5.large"]
}
variable "stateless_min_size" {
  type    = number
  default = 1
}
variable "stateless_desired_size" {
  type    = number
  default = 4
}
variable "stateless_max_size" {
  type    = number
  default = 20
}
