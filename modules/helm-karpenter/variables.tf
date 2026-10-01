# ═══════════════════════════════════════════════════════════════════
# Karpenter — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint (Karpenter needs it to register nodes)."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
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

variable "worker_role_name" {
  description = "IAM role name of the existing EKS worker nodes — reused so Karpenter-launched nodes get identical permissions and can join the cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where Karpenter launches nodes."
  type        = list(string)
}

variable "chart_version" {
  description = <<-EOT
    Pinned Karpenter Helm chart version. Must be a v1-API release (>= 1.0) since
    the NodePool/EC2NodeClass templates use apiVersion v1 / karpenter.sh/v1.
    1.7.x is a current stable line tested against EKS up to 1.36. Karpenter is
    NOT locked to a K8s version, but newer releases officially support newer EKS,
    so we track a release that explicitly covers the cluster's 1.36 control plane.
  EOT
  type        = string
  default     = "1.7.4"
}

variable "instance_categories" {
  description = "Instance families Karpenter may launch (cheapest that fits pending pods)."
  type        = list(string)
  default     = ["t", "m"]
}

variable "instance_sizes" {
  description = <<-EOT
    Instance sizes Karpenter may launch. Floor is "large" (8 GiB): "medium"
    families are only 4 GiB and get memory-overcommitted by the platform pods
    (ArgoCD, ESO, LB controller, Kong, fluentd DaemonSet, etc.), which left
    DaemonSet pods stuck Pending with "Too many pods / no allocatable memory".
    Starting at large avoids that while still consolidating down when idle.
  EOT
  type        = list(string)
  default     = ["large", "xlarge", "2xlarge"]
}

variable "capacity_types" {
  description = "spot and/or on-demand. Spot-first is cheapest; on-demand is the fallback."
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "cpu_limit" {
  description = "Max total vCPUs Karpenter may provision across all nodes it owns (cost guardrail)."
  type        = number
  default     = 32
}

variable "node_groups_ready" {
  description = "Dependency marker — ensures the seed node group exists before Karpenter installs."
  type        = any
  default     = null
}

variable "pod_identity_addon_ready" {
  description = "Dependency marker — ensures the pod identity addon is installed before association."
  type        = any
  default     = null
}
