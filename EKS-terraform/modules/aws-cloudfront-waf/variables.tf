variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "domain" {
  description = "Root domain (e.g. zordnet.com). Public entrypoint will be api.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain that fronts the microservices through CloudFront (e.g. api => api.zordnet.com)."
  type        = string
  default     = "api"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the CloudFront alias. CloudFront ONLY accepts certs from us-east-1."
  type        = string
}

variable "origin_domain_name" {
  description = "The public ALB DNS name that fronts Kong (shared internet-facing ALB created by the app repo's AWS LB Controller, e.g. k8s-zordshared-xxxx.ap-south-1.elb.amazonaws.com). CloudFront forwards traffic here. Leave empty to disable CloudFront until the ALB exists."
  type        = string
  default     = ""
}

variable "waf_rate_limit" {
  description = "Max requests allowed from a single IP within a 5-minute window before WAF blocks it."
  type        = number
  default     = 2000
}

variable "enable_bot_control" {
  description = "Enable AWS WAF Bot Control managed rule group (extra cost ~$10/mo + per-request). Recommended for public fintech APIs."
  type        = bool
  default     = true
}

variable "waf_log_retention_days" {
  description = "CloudWatch log retention (days) for WAF logs."
  type        = number
  default     = 90
}
