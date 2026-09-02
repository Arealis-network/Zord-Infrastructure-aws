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
  # NOTE: DB host + superuser creds now live in production/zord/db-connection
  # (owned by the aws-rds-postgres module, auto-populated from the RDS endpoint).
  # Infra-owned, auto-populated (no CHANGE_ME, no ignore_changes) so these always
  # reflect the LIVE current-account KMS/ACM ARNs. token-enclave reads KMS from here.
  secret_string = jsonencode({
    S3_KMS_KEY_ID             = var.s3_kms_key_arn
    ACM_CERTIFICATE_ARN       = var.acm_certificate_arn
    EVIDENCE_KMS_KEY_ARN      = var.evidence_kms_key_arn
    TOKEN_ENCLAVE_KMS_KEY_ARN = var.token_enclave_kms_key_arn
  })
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
  # DB connectivity (host/user/password/DSN) is NOT here — it comes from the
  # single Terraform-owned secret production/zord/db-connection (RDS module).
  # Only non-DB, service-specific secrets live here (fill CHANGE_ME once).
  secret_string = jsonencode({
    ZORD_VAULT_KEY     = "CHANGE_ME"
    VAULT_KEY_ID       = "CHANGE_ME"
    INTERNAL_ADMIN_KEY = "CHANGE_ME"
    EDGE_S3_BUCKET     = "zord-edge-ingress"
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
  # DB connectivity comes from production/zord/db-connection (RDS module).
  secret_string = jsonencode({
    ZORD_VAULT_KEY              = "CHANGE_ME"
    CANNONICALS3_BUCKET         = "zord-intent-engine-canonical"
    NIRS3_BUCKET                = "zord-intent-engine-nir"
    GOVERNANCES3_BUCKET         = "zord-intent-engine-governance"
    SERVICE_JWT_SIGNING_SECRET  = "CHANGE_ME"
    RELAY_SERVICES_0_AUTH_TOKEN = "CHANGE_ME"
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
  # DB connectivity comes from production/zord/db-connection (RDS module).
  # KMS_KEY_ID is auto-populated by the token-enclave KMS module (not here).
  secret_string = jsonencode({
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
  # DB connectivity comes from production/zord/db-connection (RDS module).
  secret_string = jsonencode({
    RELAY_SERVICES_0_AUTH_TOKEN = "CHANGE_ME"
    RELAY_SERVICES_1_AUTH_TOKEN = "CHANGE_ME"
    RELAY_SERVICES_2_AUTH_TOKEN = "CHANGE_ME"
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
  # DB connectivity comes from production/zord/db-connection (RDS module).
  secret_string = jsonencode({
    ZORD_VAULT_KEY    = "CHANGE_ME"
    OUTCOME_S3_BUCKET = "zord-outcome-engine-settlement-ingress"
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
  # DB connectivity comes from production/zord/db-connection (RDS module).
  secret_string = jsonencode({
    EVIDENCE_S3_BUCKET                  = "zord-evidence-vault"
    EVIDENCE_SIGNING_PRIVATE_KEY_BASE64 = ""
    EVIDENCE_KMS_KEY_ARN                = var.evidence_kms_key_arn
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
  # DB connectivity comes from production/zord/db-connection (RDS module).
  # This service currently has no non-DB secrets; kept as an empty placeholder
  # so the container exists (add keys here later if needed).
  secret_string = jsonencode({
    PLACEHOLDER = "unused"
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

# ─────────────────────────────────────────
# Observability secrets (Grafana/Kibana/Elasticsearch/Jaeger/Kong-admin UI)
# Passwords AUTO-GENERATED by Terraform (no CHANGE_ME, no manual step).
# Kept OUT of Git. Consumed by logging/tracing/api-gateway via ExternalSecrets.
# ─────────────────────────────────────────

resource "random_password" "elastic" {
  length  = 24
  special = false
}

resource "random_password" "kibana_system" {
  length  = 24
  special = false
}

resource "random_password" "kibana_encryption_key" {
  length  = 32 # Kibana requires >= 32 chars
  special = false
}

resource "random_password" "kong_admin_ui" {
  length  = 24
  special = false
}

resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "random_password" "jaeger" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "observability" {
  name                    = "${var.environment}/zord/observability-secrets"
  description             = "Observability/admin dashboard credentials (auto-generated: Grafana, Kibana, Elasticsearch, Jaeger, Kong admin UI)"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/observability-secrets" }
}

resource "aws_secretsmanager_secret_version" "observability" {
  secret_id = aws_secretsmanager_secret.observability.id
  secret_string = jsonencode({
    # Elasticsearch
    ELASTIC_USERNAME = "elastic"
    ELASTIC_PASSWORD = random_password.elastic.result

    # Kibana
    KIBANA_SYSTEM_USERNAME = "kibana_system"
    KIBANA_SYSTEM_PASSWORD = random_password.kibana_system.result
    KIBANA_ENCRYPTION_KEY  = random_password.kibana_encryption_key.result

    # Kong admin UI
    KONG_ADMIN_UI_USERNAME = "zordadmin"
    KONG_ADMIN_UI_PASSWORD = random_password.kong_admin_ui.result

    # Grafana
    GRAFANA_ADMIN_USER     = "zordadmin"
    GRAFANA_ADMIN_PASSWORD = random_password.grafana_admin.result

    # Jaeger (raw password + ready-to-use bcrypt htpasswd line for nginx)
    JAEGER_USERNAME = "zordadmin"
    JAEGER_PASSWORD = random_password.jaeger.result
    JAEGER_HTPASSWD = "zordadmin:${bcrypt(random_password.jaeger.result)}"
  })
  lifecycle { ignore_changes = [secret_string] }
}
