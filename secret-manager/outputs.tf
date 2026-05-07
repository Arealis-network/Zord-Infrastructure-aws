output "app_secret_name" {
  description = "Name of the application secret."
  value       = aws_secretsmanager_secret.this["app"].name
}

output "app_secret_arn" {
  description = "ARN of the application secret."
  value       = aws_secretsmanager_secret.this["app"].arn
}

output "edge_signing_key_secret_name" {
  description = "Name of the edge signing key secret."
  value       = aws_secretsmanager_secret.this["edge_signing_key"].name
}

output "edge_signing_key_secret_arn" {
  description = "ARN of the edge signing key secret."
  value       = aws_secretsmanager_secret.this["edge_signing_key"].arn
}
