output "release_status" {
  description = "ArgoCD Helm release status."
  value       = helm_release.argocd.status
}

output "url" {
  description = "ArgoCD UI URL."
  value       = "https://argocd.${var.domain}"
}

output "credentials_secret_name" {
  description = "Secrets Manager secret name containing ArgoCD credentials."
  value       = aws_secretsmanager_secret.argocd_credentials.name
}

output "application_mode" {
  description = "Active Application model (legacy or helm)."
  value       = var.application_mode
}

output "application_names" {
  description = "ArgoCD Application names rendered by the selected model."
  value       = sort(keys(local.applications))
}

output "application_count" {
  description = "Number of ArgoCD Applications rendered (5 in both legacy and helm modes)."
  value       = length(local.applications)
}
