# ═══════════════════════════════════════════════════════════════════
# External Secrets Operator — Variables
# ═══════════════════════════════════════════════════════════════════

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region where Secrets Manager secrets are stored."
  type        = string
}

variable "eks_name_prefix" {
  description = "Name prefix for tags (e.g., 'Arealis zord prod eks')."
  type        = string
}

variable "eks_resource_prefix" {
  description = "Resource name prefix (e.g., 'arealis-zord-prod-eks')."
  type        = string
}

variable "chart_version" {
  description = <<-EOT
    Pinned external-secrets Helm chart version. Pinned deliberately: the chart
    controls which ClusterSecretStore API versions the CRD serves, so an
    unpinned chart can silently move the API version out from under
    cluster_secret_store_api_version and break the apply.
  EOT
  type        = string
  default     = "2.10.0"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore that every ExternalSecret references. Must match the app charts' secretStoreRef.name."
  type        = string
  default     = "aws-secrets-manager"
}

variable "cluster_secret_store_api_version" {
  description = <<-EOT
    API version used for the ClusterSecretStore resource. ESO chart 2.10.0 ships
    the CRD with v1 served+storage and v1beta1 served only when
    crds.unsafeServeV1Beta1 is enabled (default false). Using v1beta1 against
    this chart fails with "no matches for kind ClusterSecretStore in version
    external-secrets.io/v1beta1". Only change this alongside chart_version.
  EOT
  type        = string
  default     = "external-secrets.io/v1"

  validation {
    condition     = can(regex("^external-secrets\\.io/v[0-9a-z]+$", var.cluster_secret_store_api_version))
    error_message = "cluster_secret_store_api_version must look like 'external-secrets.io/v1'."
  }
}

variable "namespace" {
  description = "Kubernetes namespace for External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "service_account" {
  description = "Service account name for External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs that ESO is allowed to read."
  type        = list(string)
}

variable "node_groups_ready" {
  description = "Dependency marker — ensures nodes exist before Helm install."
  type        = any
  default     = null
}
