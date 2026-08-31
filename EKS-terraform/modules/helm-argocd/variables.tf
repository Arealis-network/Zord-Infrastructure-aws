variable "node_groups_ready" {
  description = "Dependency marker — ensures nodes exist before Helm install."
  type        = any
  default     = null
}

variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "domain" {
  description = "Domain for ArgoCD UI (e.g., zordnet.com → argocd.zordnet.com)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN for HTTPS."
  type        = string
}

variable "github_username" {
  description = "GitHub username for ArgoCD repo access."
  type        = string
  default     = "Arealis-network"
}

variable "github_pat" {
  description = "GitHub Personal Access Token for ArgoCD repo access."
  type        = string
  sensitive   = true
  default     = ""
}
