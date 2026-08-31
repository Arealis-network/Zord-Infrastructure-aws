# ═══════════════════════════════════════════════════════════════════
# AWS Secrets Manager — Per-service secrets (MNC pattern)
# Each service gets its own secret with ONLY the keys it needs
# Blast radius: compromised service cannot read other services' secrets
# lifecycle ignore_changes ensures Terraform never overwrites manual edits
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# Shared Infrastructure Config (DB host, Kafka, etc.)
# Used by all services that need infra connection strings
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "shared_infra" {
  name                    = "${var.environment}/zord/shared-infra"
  description             = "Shared infrastructure config (DB host, Kafka, Redis)"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/shared-infra" }
}

resource "aws_secretsmanager_secret_version" "shared_infra" {
  secret_id = aws_secretsmanager_secret.shared_infra.id
  secret_string = jsonencode({
    POSTGRES_SUPERUSER_PASSWORD = "CHANGE_ME"
    S3_KMS_KEY_ID               = var.s3_kms_key_arn
    ACM_CERTIFICATE_ARN         = var.acm_certificate_arn
    EVIDENCE_KMS_KEY_ARN        = var.evidence_kms_key_arn
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-edge
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "edge" {
  name                    = "${var.environment}/zord/edge-secrets"
  description             = "zord-edge service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/edge-secrets" }
}

resource "aws_secretsmanager_secret_version" "edge" {
  secret_id = aws_secretsmanager_secret.edge.id
  secret_string = jsonencode({
    EDGE_DB_PASSWORD   = "CHANGE_ME"
    ZORD_VAULT_KEY     = "CHANGE_ME"
    VAULT_KEY_ID       = "CHANGE_ME"
    INTERNAL_ADMIN_KEY = "CHANGE_ME"
    EDGE_S3_BUCKET     = "zord-edge-ingress"
    EDGE_READ_DSN      = "postgres://zord_user:CHANGE_ME@zord-postgres:5432/zord_edge_db?sslmode=disable"
    JWT_SIGNING_SECRET = "CHANGE_ME"
    RELAY_AUTH_TOKEN   = "CHANGE_ME"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-intent-engine
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "intent" {
  name                    = "${var.environment}/zord/intent-engine-secrets"
  description             = "zord-intent-engine service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/intent-engine-secrets" }
}

resource "aws_secretsmanager_secret_version" "intent" {
  secret_id = aws_secretsmanager_secret.intent.id
  secret_string = jsonencode({
    INTENT_DB_PASSWORD          = "CHANGE_ME"
    ZORD_VAULT_KEY              = "CHANGE_ME"
    CANNONICALS3_BUCKET         = "zord-intent-engine-canonical"
    NIRS3_BUCKET                = "zord-intent-engine-nir"
    GOVERNANCES3_BUCKET         = "zord-intent-engine-governance"
    SERVICE_JWT_SIGNING_SECRET  = "CHANGE_ME"
    RELAY_SERVICES_0_AUTH_TOKEN = "CHANGE_ME"
    INTENT_READ_DSN             = "postgres://intent_user:CHANGE_ME@zord-postgres:5432/zord_intent_engine_db?sslmode=disable"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-token-enclave
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "token_enclave" {
  name                    = "${var.environment}/zord/token-enclave-secrets"
  description             = "zord-token-enclave service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/token-enclave-secrets" }
}

resource "aws_secretsmanager_secret_version" "token_enclave" {
  secret_id = aws_secretsmanager_secret.token_enclave.id
  secret_string = jsonencode({
    TOKEN_DB_PASSWORD                 = "CHANGE_ME"
    MASTER_KEY                        = "CHANGE_ME"
    TOKEN_SECRET                      = "CHANGE_ME"
    ENCLAVE_INTERNAL_TOKEN            = "CHANGE_ME"
    TOKENIZED_DATA_HASH_MASTER_SECRET = "CHANGE_ME"
    KMS_KEY_ID                        = "CHANGE_ME"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-relay
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "relay" {
  name                    = "${var.environment}/zord/relay-secrets"
  description             = "zord-relay service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/relay-secrets" }
}

resource "aws_secretsmanager_secret_version" "relay" {
  secret_id = aws_secretsmanager_secret.relay.id
  secret_string = jsonencode({
    RELAY_DB_PASSWORD           = "CHANGE_ME"
    RELAY_SERVICES_0_AUTH_TOKEN = "CHANGE_ME"
    RELAY_SERVICES_1_AUTH_TOKEN = "CHANGE_ME"
    RELAY_SERVICES_2_AUTH_TOKEN = "CHANGE_ME"
    RELAY_DB_URL                = "postgres://relay_user:CHANGE_ME@zord-postgres:5432/zord_relay_db?sslmode=disable"
    RELAY_READ_DSN              = "postgres://relay_user:CHANGE_ME@zord-postgres:5432/zord_relay_db?sslmode=disable"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-outcome-engine
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "outcome" {
  name                    = "${var.environment}/zord/outcome-engine-secrets"
  description             = "zord-outcome-engine service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/outcome-engine-secrets" }
}

resource "aws_secretsmanager_secret_version" "outcome" {
  secret_id = aws_secretsmanager_secret.outcome.id
  secret_string = jsonencode({
    OUTCOME_DB_PASSWORD = "CHANGE_ME"
    ZORD_VAULT_KEY      = "CHANGE_ME"
    OUTCOME_S3_BUCKET   = "zord-outcome-engine-settlement-ingress"
    OUTCOME_READ_DSN    = "postgres://outcome_user:CHANGE_ME@zord-postgres:5432/zord_outcome_db?sslmode=disable"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-evidence
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "evidence" {
  name                    = "${var.environment}/zord/evidence-secrets"
  description             = "zord-evidence service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/evidence-secrets" }
}

resource "aws_secretsmanager_secret_version" "evidence" {
  secret_id = aws_secretsmanager_secret.evidence.id
  secret_string = jsonencode({
    EVIDENCE_DB_PASSWORD                = "CHANGE_ME"
    EVIDENCE_S3_BUCKET                  = "zord-evidence-vault"
    EVIDENCE_SIGNING_PRIVATE_KEY_BASE64 = ""
    EVIDENCE_KMS_KEY_ARN                = var.evidence_kms_key_arn
    EVIDENCE_READ_DSN                   = "postgres://evidence_user:CHANGE_ME@zord-postgres:5432/zord_evidence_db?sslmode=disable"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-intelligence
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "intelligence" {
  name                    = "${var.environment}/zord/intelligence-secrets"
  description             = "zord-intelligence service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/intelligence-secrets" }
}

resource "aws_secretsmanager_secret_version" "intelligence" {
  secret_id = aws_secretsmanager_secret.intelligence.id
  secret_string = jsonencode({
    INTELLIGENCE_DB_PASSWORD  = "CHANGE_ME"
    INTELLIGENCE_DATABASE_URL = "postgres://zpi:CHANGE_ME@zord-postgres:5432/zord_intelligence?sslmode=disable"
    INTELLIGENCE_READ_DSN     = "postgres://zpi:CHANGE_ME@zord-postgres:5432/zord_intelligence?sslmode=disable"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-prompt-layer
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "prompt_layer" {
  name                    = "${var.environment}/zord/prompt-layer-secrets"
  description             = "zord-prompt-layer service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/prompt-layer-secrets" }
}

resource "aws_secretsmanager_secret_version" "prompt_layer" {
  secret_id = aws_secretsmanager_secret.prompt_layer.id
  secret_string = jsonencode({
    GEMINI_API_KEYS = "CHANGE_ME"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# zord-console
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "console" {
  name                    = "${var.environment}/zord/console-secrets"
  description             = "zord-console service secrets"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/console-secrets" }
}

resource "aws_secretsmanager_secret_version" "console" {
  secret_id = aws_secretsmanager_secret.console.id
  secret_string = jsonencode({
    JWT_SIGNING_SECRET        = "CHANGE_ME"
    SLACK_LEADS_WEBHOOK_URL   = "CHANGE_ME"
    SLACK_SUPPORT_WEBHOOK_URL = "CHANGE_ME"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# Edge Signing Key (PEM file — unchanged)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "edge_signing_key" {
  name                    = "${var.environment}/zord/edge-signing-key"
  description             = "Edge signing private key for Arealis Zord (${var.environment})"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/edge-signing-key" }
}

resource "aws_secretsmanager_secret_version" "edge_signing_key" {
  secret_id = aws_secretsmanager_secret.edge_signing_key.id
  secret_string = jsonencode({
    "ed25519_private.pem" = "-----BEGIN PRIVATE KEY-----\nCHANGE_ME\n-----END PRIVATE KEY-----"
  })
  lifecycle { ignore_changes = [secret_string] }
}

# ─────────────────────────────────────────
# Evidence Signing Key (PEM file — unchanged)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "evidence_signing_key" {
  name                    = "${var.environment}/zord/evidence-signing-key"
  description             = "Evidence signing private key for Arealis Zord (${var.environment})"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/evidence-signing-key" }
}

resource "aws_secretsmanager_secret_version" "evidence_signing_key" {
  secret_id = aws_secretsmanager_secret.evidence_signing_key.id
  secret_string = jsonencode({
    "signing_key.pem" = "-----BEGIN PRIVATE KEY-----\nCHANGE_ME\n-----END PRIVATE KEY-----"
  })
  lifecycle { ignore_changes = [secret_string] }
}
