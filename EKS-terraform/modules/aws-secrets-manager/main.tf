# ═══════════════════════════════════════════════════════════════════
# AWS Secrets Manager — Per-service secrets (MNC pattern)
# Each service gets its own secret with ONLY the keys it needs
# Blast radius: compromised service cannot read other services' secrets
# lifecycle ignore_changes ensures Terraform never overwrites manual edits
# ═══════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════
# AUTO-GENERATED SECRET VALUES (no CHANGE_ME, no hardcoding)
# Random strings generated once by Terraform and frozen. Shared values are
# generated ONCE and replicated to every consumer's secret so they always match.
# ═══════════════════════════════════════════════════════════════════

# ── Per-service vault keys — EXACTLY 32 bytes, base64-encoded.
# The services require a 32-byte key (they base64-decode ZORD_VAULT_KEY). Using
# random_bytes(32) -> base64 guarantees the decoded value is exactly 32 bytes.
# (A 32-char random_password base64-decodes to ~24 bytes and fails validation.)
resource "random_bytes" "edge_vault_key" {
  length = 32
}
resource "random_bytes" "intent_vault_key" {
  length = 32
}
resource "random_bytes" "outcome_vault_key" {
  length = 32
}

# ── Per-service unique secrets ──
resource "random_password" "edge_vault_key_id" {
  length  = 20
  special = false
}
resource "random_password" "edge_internal_admin_key" {
  length  = 32
  special = false
}
resource "random_password" "token_master_key" {
  length  = 32
  special = false
}
resource "random_password" "token_secret" {
  length  = 32
  special = false
}
resource "random_password" "token_enclave_internal_token" {
  length  = 32
  special = false
}
resource "random_password" "tokenized_data_hash_master_secret" {
  length  = 32
  special = false
}

# ── SHARED: internal service token (console signs -> intent verifies, must match) ──
resource "random_password" "intent_engine_internal_service_token" {
  length  = 40
  special = false
}

# ── Evidence service internal key ──
resource "random_password" "evidence_internal_key" {
  length  = 32
  special = false
}

# ── Kafka SCRAM user for token-enclave (consumes pii.tokenize.request/result) ──
resource "random_password" "kafka_token" {
  length  = 28
  special = false
}

# ── SHARED auth secrets (generated ONCE, same value in all consumers) ──
resource "random_password" "jwt_signing_secret" { # edge signs; kong/intelligence/outcome/console verify
  length  = 48
  special = false
}
resource "random_password" "service_jwt_signing_secret" { # intent signs; token-enclave verifies
  length  = 48
  special = false
}
resource "random_password" "relay_slot_0_token" { # relay <-> intent
  length  = 32
  special = false
}
resource "random_password" "relay_slot_1_token" { # relay <-> edge
  length  = 32
  special = false
}
resource "random_password" "relay_slot_2_token" { # relay <-> outcome
  length  = 32
  special = false
}

# ── Evidence signing key — stable Ed25519, generated ONCE. Regenerating would
#    make previously-signed evidence packs unverifiable, so this is created once
#    and frozen (ignore_changes on the secret). Stored base64 in evidence-secrets.
resource "tls_private_key" "evidence_signing" {
  algorithm = "ED25519"
}

# ── Kafka SCRAM: per-service users + admin (SASL_PLAINTEXT / SCRAM-SHA-512) ──
resource "random_password" "kafka_admin" {
  length  = 28
  special = false
}
resource "random_password" "kafka_edge" {
  length  = 28
  special = false
}
resource "random_password" "kafka_intent" {
  length  = 28
  special = false
}
resource "random_password" "kafka_outcome" {
  length  = 28
  special = false
}
resource "random_password" "kafka_evidence" {
  length  = 28
  special = false
}
resource "random_password" "kafka_intelligence" {
  length  = 28
  special = false
}
resource "random_password" "kafka_relay" {
  length  = 28
  special = false
}
resource "random_password" "kafka_ml" {
  length  = 28
  special = false
}

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

    # SHARED auth secrets — one value, every consumer reads the SAME one (must match).
    JWT_SIGNING_SECRET         = random_password.jwt_signing_secret.result         # edge signs; kong/intelligence/outcome/console verify
    SERVICE_JWT_SIGNING_SECRET = random_password.service_jwt_signing_secret.result # intent signs; token-enclave verifies
    RELAY_SLOT_0_TOKEN         = random_password.relay_slot_0_token.result         # relay <-> intent
    RELAY_SLOT_1_TOKEN         = random_password.relay_slot_1_token.result         # relay <-> edge
    RELAY_SLOT_2_TOKEN         = random_password.relay_slot_2_token.result         # relay <-> outcome
  })
}

# ─────────────────────────────────────────
# Kafka SCRAM credentials (SHARED) — the scram-users-job provisions these users,
# and each service authenticates with its own user/password. ONE source of truth
# so the job and the services always agree. SASL_PLAINTEXT + SCRAM-SHA-512.
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "kafka" {
  name                    = "${var.environment}/zord/kafka-secrets"
  description             = "Kafka SCRAM users (admin + per-service) — auto-generated"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.environment}/zord/kafka-secrets" }
}

resource "aws_secretsmanager_secret_version" "kafka" {
  secret_id = aws_secretsmanager_secret.kafka.id
  secret_string = jsonencode({
    # admin (Kafka super user) + broker JAAS used by the statefulset
    KAFKA_ADMIN_USERNAME     = "admin"
    KAFKA_ADMIN_PASSWORD     = random_password.kafka_admin.result
    KAFKA_BROKER_JAAS_CONFIG = "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"admin\" password=\"${random_password.kafka_admin.result}\";"

    # per-service SCRAM users (username fixed, password auto-gen)
    KAFKA_EDGE_USERNAME         = "edge-service"
    KAFKA_EDGE_PASSWORD         = random_password.kafka_edge.result
    KAFKA_INTENT_USERNAME       = "intent-service"
    KAFKA_INTENT_PASSWORD       = random_password.kafka_intent.result
    KAFKA_OUTCOME_USERNAME      = "outcome-service"
    KAFKA_OUTCOME_PASSWORD      = random_password.kafka_outcome.result
    KAFKA_EVIDENCE_USERNAME     = "evidence-service"
    KAFKA_EVIDENCE_PASSWORD     = random_password.kafka_evidence.result
    KAFKA_INTELLIGENCE_USERNAME = "intelligence-service"
    KAFKA_INTELLIGENCE_PASSWORD = random_password.kafka_intelligence.result
    KAFKA_RELAY_USERNAME        = "relay-service"
    KAFKA_RELAY_PASSWORD        = random_password.kafka_relay.result
    KAFKA_ML_USERNAME           = "ml-service"
    KAFKA_ML_PASSWORD           = random_password.kafka_ml.result
    KAFKA_TOKEN_USERNAME        = "token-enclave-service"
    KAFKA_TOKEN_PASSWORD        = random_password.kafka_token.result
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
    ZORD_VAULT_KEY     = random_bytes.edge_vault_key.base64
    VAULT_KEY_ID       = random_password.edge_vault_key_id.result
    INTERNAL_ADMIN_KEY = random_password.edge_internal_admin_key.result
    EDGE_S3_BUCKET     = "zord-edge-ingress"
    JWT_SIGNING_SECRET = random_password.jwt_signing_secret.result # shared (edge signs)
    RELAY_AUTH_TOKEN   = random_password.relay_slot_1_token.result # edge = relay slot 1
    KAFKA_USERNAME     = "edge-service"
    KAFKA_PASSWORD     = random_password.kafka_edge.result
  })
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
    ZORD_VAULT_KEY                       = random_bytes.intent_vault_key.base64
    CANNONICALS3_BUCKET                  = "zord-intent-engine-canonical"
    NIRS3_BUCKET                         = "zord-intent-engine-nir"
    GOVERNANCES3_BUCKET                  = "zord-intent-engine-governance"
    SERVICE_JWT_SIGNING_SECRET           = random_password.service_jwt_signing_secret.result           # shared (intent signs)
    JWT_SIGNING_SECRET                   = random_password.jwt_signing_secret.result                   # shared (verifies edge JWT)
    TOKENIZED_DATA_HASH_MASTER_SECRET    = random_password.tokenized_data_hash_master_secret.result    # shared with token-enclave
    INTENT_ENGINE_INTERNAL_SERVICE_TOKEN = random_password.intent_engine_internal_service_token.result # shared (console -> intent)
    RELAY_SERVICES_0_AUTH_TOKEN          = random_password.relay_slot_0_token.result                   # intent = relay slot 0
    KAFKA_USERNAME                       = "intent-service"
    KAFKA_PASSWORD                       = random_password.kafka_intent.result
  })
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
    MASTER_KEY                        = random_password.token_master_key.result
    TOKEN_SECRET                      = random_password.token_secret.result
    ENCLAVE_INTERNAL_TOKEN            = random_password.token_enclave_internal_token.result
    TOKENIZED_DATA_HASH_MASTER_SECRET = random_password.tokenized_data_hash_master_secret.result
    SERVICE_JWT_SIGNING_SECRET        = random_password.service_jwt_signing_secret.result # shared (token-enclave verifies intent's JWT)
    KMS_KEY_ID                        = var.token_enclave_kms_key_arn                     # live current-account ARN
    KAFKA_USERNAME                    = "token-enclave-service"
    KAFKA_PASSWORD                    = random_password.kafka_token.result
  })
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
    RELAY_SERVICES_0_AUTH_TOKEN = random_password.relay_slot_0_token.result # matches intent
    RELAY_SERVICES_1_AUTH_TOKEN = random_password.relay_slot_1_token.result # matches edge
    RELAY_SERVICES_2_AUTH_TOKEN = random_password.relay_slot_2_token.result # matches outcome
    KAFKA_USERNAME              = "relay-service"
    KAFKA_PASSWORD              = random_password.kafka_relay.result
  })
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
    ZORD_VAULT_KEY     = random_bytes.outcome_vault_key.base64
    OUTCOME_S3_BUCKET  = "zord-outcome-engine-settlement-ingress"
    JWT_SIGNING_SECRET = random_password.jwt_signing_secret.result # shared (outcome verifies)
    RELAY_AUTH_TOKEN   = random_password.relay_slot_2_token.result # outcome = relay slot 2
    KAFKA_USERNAME     = "outcome-service"
    KAFKA_PASSWORD     = random_password.kafka_outcome.result
  })
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
    EVIDENCE_S3_BUCKET = "zord-evidence-vault"
    # Stable Ed25519 signing key (base64 of the PEM), generated once by Terraform.
    EVIDENCE_SIGNING_PRIVATE_KEY_BASE64 = base64encode(tls_private_key.evidence_signing.private_key_pem)
    EVIDENCE_KMS_KEY_ARN                = var.evidence_kms_key_arn
    EVIDENCE_INTERNAL_KEY               = random_password.evidence_internal_key.result
    JWT_SIGNING_SECRET                  = random_password.jwt_signing_secret.result # shared (verifies edge JWT)
    RELAY_AUTH_TOKEN                    = random_password.relay_slot_2_token.result # evidence uses relay via slot 2 (shared w/ outcome)
    KAFKA_USERNAME                      = "evidence-service"
    KAFKA_PASSWORD                      = random_password.kafka_evidence.result
  })
  # Freeze so the signing key is never regenerated (would break old-pack verification).
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
    JWT_SIGNING_SECRET = random_password.jwt_signing_secret.result # shared (intelligence verifies)
    KAFKA_USERNAME     = "intelligence-service"
    KAFKA_PASSWORD     = random_password.kafka_intelligence.result
  })
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
    JWT_SIGNING_SECRET                   = random_password.jwt_signing_secret.result                   # shared (console verifies)
    INTENT_ENGINE_INTERNAL_SERVICE_TOKEN = random_password.intent_engine_internal_service_token.result # shared (console -> intent, must match)
    SLACK_LEADS_WEBHOOK_URL              = "CHANGE_ME"                                                 # real webhook — human-provided
    SLACK_SUPPORT_WEBHOOK_URL            = "CHANGE_ME"                                                 # real webhook — human-provided

    # SMTP (email). Non-secret values set here; PASSWORD is a real Gmail app
    # password — set it in the Secrets Manager Console, never commit it to Git.
    SMTP_HOST = "smtp.gmail.com"
    SMTP_PORT = "587"
    SMTP_USER = "careers@arealis.io"
    SMTP_FROM = "Arealis Zord <careers@arealis.io>"
    SMTP_PASS = "CHANGE_ME"
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
