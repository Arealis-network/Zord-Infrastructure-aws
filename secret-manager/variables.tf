variable "aws_region" {
  description = "AWS region where Secrets Manager secrets will be created."
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment. Must be staging or production."
  type        = string
  default     = "production"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "project_name" {
  description = "Project tag value."
  type        = string
  default     = "arealis-zord-secrets"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "yaswanth"
}

variable "app_secret_name" {
  description = "AWS Secrets Manager secret name for the app secret bundle (without environment prefix)."
  type        = string
  default     = "zord/app-secrets"
}

variable "edge_signing_key_secret_name" {
  description = "AWS Secrets Manager secret name for the edge signing key (without environment prefix)."
  type        = string
  default     = "zord/edge-signing-key"
}

variable "evidence_signing_key_secret_name" {
  description = "AWS Secrets Manager secret name for the evidence signing key (without environment prefix)."
  type        = string
  default     = "zord/evidence-signing-key"
}

variable "kms_key_id" {
  description = "Optional customer-managed KMS key ARN or ID for secret encryption. Leave empty to use the default aws/secretsmanager key."
  type        = string
  default     = ""
}

variable "recovery_window_in_days" {
  description = "Days to keep a deleted secret recoverable. Set 0 for force delete without recovery."
  type        = number
  default     = 0

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}
