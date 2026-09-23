variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging, or production."
  }
}

variable "domain" {
  description = "Root domain used for the public CloudFront entrypoint."
  type        = string
}

variable "subdomain" {
  description = "Primary subdomain that fronts the origin through CloudFront."
  type        = string
  default     = "api"
}

variable "public_fqdns" {
  description = "Public FQDNs served as CloudFront aliases (api/www/kong-admin). Aliased to CloudFront by the caller."
  type        = list(string)
  default     = []
}

variable "origin_domain_name" {
  description = "Origin DNS name. Leave empty to disable the CloudFront and WAF resources."
  type        = string
  default     = ""
}

variable "waf_rate_limit" {
  description = "Maximum requests allowed from one IP in a five-minute window before WAF blocks it."
  type        = number
  default     = 2000
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate in us-east-1 used by the CloudFront alias."
  type        = string
}
