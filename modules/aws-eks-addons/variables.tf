# ═══════════════════════════════════════════════════════════════════
# EKS Core Addons — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "stateful_node_group_id" {
  description = "Stateful node group ID (for depends_on)."
  type        = string
}

variable "stateless_node_group_id" {
  description = "Stateless node group ID (for depends_on)."
  type        = string
}
