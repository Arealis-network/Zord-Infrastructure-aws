variable "cluster_name" {
  description = "EKS cluster name (used as TXT owner ID)."
  type        = string
}

variable "domain" {
  description = "Hosted zone domain filter (e.g. zordnet.com). External DNS only manages records in this zone."
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
  description = "Pinned external-dns Helm chart version (free/OSS). Latest stable: 1.21.1."
  type        = string
  default     = "1.21.1"
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
