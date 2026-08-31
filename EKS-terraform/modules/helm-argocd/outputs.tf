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
