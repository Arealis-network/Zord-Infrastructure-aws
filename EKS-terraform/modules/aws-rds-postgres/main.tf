# ═══════════════════════════════════════════════════════════════════
# RDS PostgreSQL — managed database for all Zord microservices
#
# ONE RDS instance hosts ALL service databases (created by the app team's
# bootstrap job): zord_edge_db, zord_intent_engine_db, zord_relay_db,
# zord_outcome_db, zord_evidence_db, zord_intelligence, zord_token_db,
# zord_prompt_layer_db (8 databases).
#
# Free-tier defaults: db.t3.micro, 20 GB, single-AZ. Scale to paid by changing
# instance_class / allocated_storage / multi_az (one-line each).
#
# Self-contained: subnet group + security group + KMS-encrypted instance +
# auto-generated master password written to Secrets Manager (single source of
# truth — no manual password typing).
#
# Private only: no public IP; ingress on 5432 locked to the EKS cluster SG.
# ═══════════════════════════════════════════════════════════════════

locals {
  identifier = "${var.eks_resource_prefix}-postgres"
}

# ─────────────────────────────────────────
# Master password — Terraform-generated (single source of truth)
# ─────────────────────────────────────────

resource "random_password" "master" {
  length  = 24
  special = false # keep RDS-safe (no chars RDS rejects)
}

# ─────────────────────────────────────────
# DB subnet group — private subnets only
# ─────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name       = "${var.eks_resource_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.eks_name_prefix} db subnet group"
  }
}

# ─────────────────────────────────────────
# Security group — 5432 open ONLY to the EKS cluster SG
# ─────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.eks_resource_prefix}-rds-sg"
  description = "RDS Postgres - allow 5432 only from the EKS cluster"
  vpc_id      = var.vpc_id

  # Allow 5432 from the EKS cluster SG (pods/nodes carry this SG by default).
  ingress {
    description     = "Postgres from EKS cluster SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
  }

  # Also allow 5432 from anywhere inside the VPC. This matches the app team's
  # NetworkPolicy (egress to the VPC CIDR) and avoids cluster-SG vs node-SG
  # ambiguity. Still fully private — no public access (RDS has no public IP).
  ingress {
    description = "Postgres from within the VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.eks_name_prefix} rds sg"
  }
}

# ─────────────────────────────────────────
# RDS PostgreSQL instance
# ─────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier     = local.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = "zord" # placeholder DB; per-service DBs created by app bootstrap
  username = var.master_username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_days
  deletion_protection     = false # dev: allow destroy. Set true for real production.
  skip_final_snapshot     = true  # dev: no final snapshot on destroy. Set false for prod.

  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.eks_name_prefix} postgres"
  }
}

# ─────────────────────────────────────────
# Dedicated DB connection secret (Terraform-owned, single source of truth).
# ESO delivers this to pods; the app bootstrap uses it to create per-service
# databases/users on this instance. Own secret (not shared-infra) so the RDS
# module fully owns it and there is no conflicting secret_version writer.
# No ignore_changes — endpoint/password are Terraform-owned and stay in sync.
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "db_connection" {
  name                    = "${var.environment}/zord/db-connection"
  description             = "RDS PostgreSQL connection (endpoint + master creds) for ${var.environment}"
  recovery_window_in_days = 0

  tags = {
    Name    = "${var.environment}/zord/db-connection"
    Service = "rds-postgres"
  }
}

# One host, one user, one password — shared by ALL services and all 7 databases.
# The app bootstrap creates the 7 databases on this instance using these creds.
# Every service connects with DB_USER + DB_PASSWORD to its DB_*_NAME database.
resource "aws_secretsmanager_secret_version" "db_connection" {
  secret_id = aws_secretsmanager_secret.db_connection.id

  secret_string = jsonencode({
    DB_HOST     = aws_db_instance.this.address
    DB_PORT     = "5432"
    DB_SSLMODE  = "require"
    DB_USER     = var.master_username
    DB_PASSWORD = random_password.master.result

    # Per-service database names (all on this one instance)
    EDGE_DB_NAME         = "zord_edge_db"
    INTENT_DB_NAME       = "zord_intent_engine_db"
    RELAY_DB_NAME        = "zord_relay_db"
    OUTCOME_DB_NAME      = "zord_outcome_db"
    EVIDENCE_DB_NAME     = "zord_evidence_db"
    INTELLIGENCE_DB_NAME = "zord_intelligence"
    TOKEN_DB_NAME        = "zord_token_db"
    PROMPTLAYER_DB_NAME  = "zord_prompt_layer_db"

    # Ready-to-use DSN strings for services whose code reads a full connection
    # string (Group B: relay, intelligence, prompt-layer). Built automatically
    # from the RDS endpoint + the single shared password — no CHANGE_ME, no sync.
    EDGE_DSN                  = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_edge_db?sslmode=require"
    INTENT_DSN                = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_intent_engine_db?sslmode=require"
    RELAY_DB_URL              = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_relay_db?sslmode=require"
    RELAY_DSN                 = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_relay_db?sslmode=require"
    OUTCOME_DSN               = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_outcome_db?sslmode=require"
    EVIDENCE_DSN              = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_evidence_db?sslmode=require"
    INTELLIGENCE_DATABASE_URL = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_intelligence?sslmode=require"
    TOKEN_DSN                 = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_token_db?sslmode=require"

    # prompt-layer's own vector-index dedupe state DB (VECTOR_INDEX_STATE_DSN).
    PROMPTLAYER_DSN        = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_prompt_layer_db?sslmode=require"
    VECTOR_INDEX_STATE_DSN = "postgres://${var.master_username}:${random_password.master.result}@${aws_db_instance.this.address}:5432/zord_prompt_layer_db?sslmode=require"
  })
}
