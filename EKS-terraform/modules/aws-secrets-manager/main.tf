# ═══════════════════════════════════════════════════════════════════
# AWS Secrets Manager — Creates secrets with all key names pre-filled
# Terraform creates the structure, you edit real values in AWS Console
# lifecycle ignore_changes ensures Terraform never overwrites your edits
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# Secret 1: App Secrets (all service env vars)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.environment}/zord/app-secrets"
  description             = "Application secret bundle for Arealis Zord workloads (${var.environment})"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.environment}/zord/app-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id

  secret_string = jsonencode({
    # ── Database Passwords ──
    POSTGRES_SUPERUSER_PASSWORD = "CHANGE_ME"
    EDGE_DB_PASSWORD            = "CHANGE_ME"
    INTENT_DB_PASSWORD          = "CHANGE_ME"
    RELAY_DB_PASSWORD           = "CHANGE_ME"
    TOKEN_DB_PASSWORD           = "CHANGE_ME"
    OUTCOME_DB_PASSWORD         = "CHANGE_ME"
    EVIDENCE_DB_PASSWORD        = "CHANGE_ME"
    INTELLIGENCE_DB_PASSWORD    = "CHANGE_ME"

    # ── Encryption & Auth Keys ──
    ZORD_VAULT_KEY                         = "CHANGE_ME"
    INTERNAL_ADMIN_KEY                     = "CHANGE_ME"
    MASTER_KEY                             = "CHANGE_ME"
    TOKEN_SECRET                           = "CHANGE_ME"
    JWT_SIGNING_SECRET                     = "CHANGE_ME"
    ENCLAVE_INTERNAL_TOKEN                 = "CHANGE_ME"
    EVIDENCE_SIGNING_PRIVATE_KEY_BASE64    = ""
    EVIDENCE_ARCHIVE_ENCRYPTION_KEY_BASE64 = "CHANGE_ME"
    TOKENIZED_DATA_HASH_MASTER_SECRET      = "CHANGE_ME"

    # ── External API Keys ──
    GEMINI_API_KEYS = "CHANGE_ME"

    # ── S3 Bucket Names ──
    EDGE_S3_BUCKET       = "zord-edge-ingress"
    CANONICAL_S3_BUCKET  = "zord-intent-engine-canonical"
    NIR_S3_BUCKET        = "zord-intent-engine-nir"
    GOVERNANCE_S3_BUCKET = "zord-intent-engine-governance"
    OUTCOME_S3_BUCKET    = "zord-outcome-engine-settlement-ingress"
    EVIDENCE_S3_BUCKET   = "zord-evidence-vault"

    # ── S3 Encryption (KMS) ──
    S3_KMS_KEY_ID = var.s3_kms_key_arn

    # ── ACM Certificate ──
    ACM_CERTIFICATE_ARN = var.acm_certificate_arn

    # ── Relay Auth Tokens ──
    RELAY_SERVICES_0_AUTH_TOKEN = "CHANGE_ME"
    RELAY_SERVICES_1_AUTH_TOKEN = "CHANGE_ME"
    RELAY_SERVICES_2_AUTH_TOKEN = "CHANGE_ME"

    # ── Database Connection Strings ──
    RELAY_DB_URL              = "postgres://relay_user:CHANGE_ME@zord-postgres:5432/zord_relay_db?sslmode=disable"
    INTELLIGENCE_DATABASE_URL = "postgres://zpi:CHANGE_ME@zord-postgres:5432/zord_intelligence?sslmode=disable"
    EDGE_READ_DSN             = "postgres://zord_user:CHANGE_ME@zord-postgres:5432/zord_edge_db?sslmode=disable"
    INTENT_READ_DSN           = "postgres://intent_user:CHANGE_ME@zord-postgres:5432/zord_intent_engine_db?sslmode=disable"
    RELAY_READ_DSN            = "postgres://relay_user:CHANGE_ME@zord-postgres:5432/zord_relay_db?sslmode=disable"
    INTELLIGENCE_READ_DSN     = "postgres://zpi:CHANGE_ME@zord-postgres:5432/zord_intelligence?sslmode=disable"
    EVIDENCE_READ_DSN         = "postgres://evidence_user:CHANGE_ME@zord-postgres:5432/zord_evidence_db?sslmode=disable"
    OUTCOME_READ_DSN          = "postgres://outcome_user:CHANGE_ME@zord-postgres:5432/zord_outcome_db?sslmode=disable"

    # ── Slack Webhooks ──
    SLACK_LEADS_WEBHOOK_URL   = "CHANGE_ME"
    SLACK_SUPPORT_WEBHOOK_URL = "CHANGE_ME"
  })

  # IMPORTANT: Terraform will NOT overwrite values you edit in AWS Console
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ─────────────────────────────────────────
# Secret 2: Edge Signing Key (PEM file)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "edge_signing_key" {
  name                    = "${var.environment}/zord/edge-signing-key"
  description             = "Edge signing private key for Arealis Zord (${var.environment})"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.environment}/zord/edge-signing-key"
  }
}

resource "aws_secretsmanager_secret_version" "edge_signing_key" {
  secret_id = aws_secretsmanager_secret.edge_signing_key.id

  secret_string = jsonencode({
    "ed25519_private.pem" = "-----BEGIN PRIVATE KEY-----\nCHANGE_ME\n-----END PRIVATE KEY-----"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ─────────────────────────────────────────
# Secret 3: Evidence Signing Key (PEM file)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "evidence_signing_key" {
  name                    = "${var.environment}/zord/evidence-signing-key"
  description             = "Evidence signing private key for Arealis Zord (${var.environment})"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.environment}/zord/evidence-signing-key"
  }
}

resource "aws_secretsmanager_secret_version" "evidence_signing_key" {
  secret_id = aws_secretsmanager_secret.evidence_signing_key.id

  secret_string = jsonencode({
    "signing_key.pem" = "-----BEGIN PRIVATE KEY-----\nCHANGE_ME\n-----END PRIVATE KEY-----"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
