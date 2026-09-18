##########################################################################
# Shared declarations copied into each independently state-locked component.
# Environment values are loaded from live/environments/<env>/config.json.
##########################################################################

variable "environment" {
  description = "Environment config to load (dev, staging, production)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging or production."
  }
}

variable "state_bucket" {
  description = "S3 bucket holding all component state files."
  type        = string
}

variable "github_pat" {
  description = "GitHub PAT used by ArgoCD. Required only by 05-platform."
  type        = string
  default     = ""
  sensitive   = true
}

locals {
  config = jsondecode(file("${path.module}/../../environments/${var.environment}/config.json"))

  env_short = local.config.environment == "production" ? "prod" : (local.config.environment == "staging" ? "stg" : "dev")

  common_tags = {
    Environment = local.config.environment
    Project     = "arealis-zord-eks"
    Owner       = "yaswanth"
    ManagedBy   = "Terraform"
    Cluster     = local.config.cluster_name
  }

  state_keys = {
    foundation = "eks/${var.environment}/01-foundation.tfstate"
    data       = "eks/${var.environment}/02-data.tfstate"
    compute    = "eks/${var.environment}/03-compute.tfstate"
    security   = "eks/${var.environment}/04-security.tfstate"
    platform   = "eks/${var.environment}/05-platform.tfstate"
    edge       = "eks/${var.environment}/06-edge.tfstate"
  }
}
