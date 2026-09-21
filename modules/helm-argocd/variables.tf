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
  description = "Apex domain used to build the ArgoCD host. Must be the domain the shared wildcard ACM cert covers (e.g. zordnet.com), because an ALB HTTPS listener can only auto-discover a cert whose wildcard matches the host by ONE label."
  type        = string
}

variable "host_prefix" {
  description = "Per-env prefix for the ArgoCD hostname so every env stays a SINGLE label under the apex and is covered by the one *.<domain> cert. Empty for production (argocd.<domain>); 'stg-' / 'dev-' for non-prod (stg-argocd.<domain>)."
  type        = string
  default     = ""
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

variable "apps_chart_version" {
  description = "Pinned argocd-apps Helm chart version (creates the Application CRs after the main install)."
  type        = string
  default     = "2.0.2"
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

# ── Application source model ──
variable "application_mode" {
  description = "ArgoCD Application model: legacy keeps the original manifest-path Applications (production migration safety); helm creates the 5 Helm Applications (zord-platform umbrella + kong + logging + monitoring + tracing)."
  type        = string
  default     = "legacy"

  validation {
    condition     = contains(["legacy", "helm"], var.application_mode)
    error_message = "application_mode must be legacy or helm."
  }
}

variable "app_target_revision" {
  description = "Git revision ArgoCD watches (staging, master/dev, main/prod, or a custom Jenkins branch)."
  type        = string
  default     = "main"
}

variable "values_environment" {
  description = "Directory under kubernetes/values (prod, staging, dev)."
  type        = string
  default     = "prod"
}

variable "applications_auto_sync" {
  description = "Enable automatic sync/prune/self-heal for Helm Applications. Keep false until Jenkins replaces all *-PLACEHOLDER image tags. NOTE: platform and kong are NEVER auto-synced regardless of this flag."
  type        = bool
  default     = false
}

variable "observability_auto_sync" {
  description = "Declaratively enable ArgoCD auto-sync for logging/monitoring/tracing. These use pinned public images (no Jenkins build), so they can converge on their own as soon as the cluster is up — no kubectl patching from CI. Platform and Kong remain manual."
  type        = bool
  default     = true
}

variable "application_name_suffix" {
  description = "Suffix appended to Helm Application names (prod/staging/dev)."
  type        = string
  default     = "prod"
}
