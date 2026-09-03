variable "chart_version" {
  description = "metrics-server Helm chart version."
  type        = string
  default     = "3.12.2"
}

variable "node_groups_ready" {
  description = "Dependency handle — ensures node groups exist before installing metrics-server."
  type        = any
  default     = null
}
