output "release_status" {
  description = "Argo Rollouts Helm release status."
  value       = helm_release.argo_rollouts.status
}
