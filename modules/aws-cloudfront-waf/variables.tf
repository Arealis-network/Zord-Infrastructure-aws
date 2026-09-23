variable "environment" {
  description = "Deployment environment (staging or production)."
  type        = string
}

variable "domain" {
  description = "Root domain (e.g. zordnet.com). Public entrypoint will be api.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Primary subdomain (e.g. api). Used as the primary alias and in public_fqdn."
  type        = string
  default     = "api"
}

variable "public_fqdns" {
  description = "Public FQDNs served as CloudFront aliases (api/www/kong-admin). Defaults to <subdomain>.<domain>."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the CloudFront alias. CloudFront ONLY accepts certs from us-east-1."
  type        = string
}

variable "origin_domain_name" {
  description = "CloudFront origin (stable origin host that External DNS points at the ALB). Empty = edge disabled."
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
