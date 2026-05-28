terraform {
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  secrets = {
    app = {
      name        = "${var.environment}/${var.app_secret_name}"
      description = "Application secret bundle for Arealis Zord workloads (${var.environment})"
    }
    edge_signing_key = {
      name        = "${var.environment}/${var.edge_signing_key_secret_name}"
      description = "Edge signing private key for Arealis Zord (${var.environment})"
    }
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = local.secrets

  name                    = each.value.name
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null

  tags = {
    Name = each.value.name
  }
}
