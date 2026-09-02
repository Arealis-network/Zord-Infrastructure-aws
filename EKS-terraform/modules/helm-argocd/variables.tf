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

variable "shared_alb_group" {
  description = "AWS LB Controller ingress group.name for the single shared ALB. ArgoCD and Kong join the same group so ALL hosts share ONE load balancer."
  type        = string
  default     = "zord-shared-alb"
}

variable "chart_version" {
  description = "Pinned argo-cd Helm chart version (free/open-source). Latest stable: 10.4.1."
  type        = string
  default     = "10.4.1"
}

variable "github_username" {
  description = "GitHub username for ArgoCD repo access."
  type        = string
  default     = "Arealis-network"
}

variable "app_repo_url" {
  description = "Git URL of the app repo ArgoCD deploys from (holds kubernetes/eks + kubernetes/monitoring)."
  type        = string
  default     = "https://github.com/Arealis-network/Arealis-Zord-intent.git"
}

variable "github_pat" {
  description = "GitHub Personal Access Token for ArgoCD repo access."
  type        = string
  sensitive   = true
  default     = ""
}
