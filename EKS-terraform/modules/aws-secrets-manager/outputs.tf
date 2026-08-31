# ═══════════════════════════════════════════════════════════════════
# AWS Secrets Manager — Outputs
# ═══════════════════════════════════════════════════════════════════

output "secret_arns" {
  description = "Map of all service secret ARNs."
  value = {
    shared_infra         = aws_secretsmanager_secret.shared_infra.arn
    edge                 = aws_secretsmanager_secret.edge.arn
    intent               = aws_secretsmanager_secret.intent.arn
    token_enclave        = aws_secretsmanager_secret.token_enclave.arn
    relay                = aws_secretsmanager_secret.relay.arn
    outcome              = aws_secretsmanager_secret.outcome.arn
    evidence             = aws_secretsmanager_secret.evidence.arn
    intelligence         = aws_secretsmanager_secret.intelligence.arn
    prompt_layer         = aws_secretsmanager_secret.prompt_layer.arn
    console              = aws_secretsmanager_secret.console.arn
    edge_signing_key     = aws_secretsmanager_secret.edge_signing_key.arn
    evidence_signing_key = aws_secretsmanager_secret.evidence_signing_key.arn
  }
}

output "secret_names" {
  description = "Map of all service secret names."
  value = {
    shared_infra         = aws_secretsmanager_secret.shared_infra.name
    edge                 = aws_secretsmanager_secret.edge.name
    intent               = aws_secretsmanager_secret.intent.name
    token_enclave        = aws_secretsmanager_secret.token_enclave.name
    relay                = aws_secretsmanager_secret.relay.name
    outcome              = aws_secretsmanager_secret.outcome.name
    evidence             = aws_secretsmanager_secret.evidence.name
    intelligence         = aws_secretsmanager_secret.intelligence.name
    prompt_layer         = aws_secretsmanager_secret.prompt_layer.name
    console              = aws_secretsmanager_secret.console.name
    edge_signing_key     = aws_secretsmanager_secret.edge_signing_key.name
    evidence_signing_key = aws_secretsmanager_secret.evidence_signing_key.name
  }
}
