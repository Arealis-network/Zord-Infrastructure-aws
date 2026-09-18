output "cluster_autoscaler_release_status" {
  description = "Cluster Autoscaler Helm release status."
  value       = module.cluster_autoscaler.release_status
}

output "external_secrets_release_status" {
  description = "External Secrets Operator Helm release status."
  value       = module.external_secrets.release_status
}

output "argo_rollouts_release_status" {
  description = "Argo Rollouts Helm release status."
  value       = module.argo_rollouts.release_status
}

output "argocd_release_status" {
  description = "Argo CD Helm release status."
  value       = module.argocd.release_status
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver."
  value       = module.ebs_csi.role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by Cluster Autoscaler."
  value       = module.cluster_autoscaler.role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator."
  value       = module.external_secrets.role_arn
}

output "argocd_url" {
  description = "Argo CD UI URL."
  value       = module.argocd.url
}

output "argocd_credentials_secret_name" {
  description = "Secrets Manager secret containing Argo CD credentials."
  value       = module.argocd.credentials_secret_name
}

output "platform_ready" {
  description = "Indicates that the platform composition is represented in the graph."
  value       = true
}
