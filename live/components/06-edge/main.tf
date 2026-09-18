terraform {
  required_version = ">= 1.11.0"
  backend "s3" {}
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = local.config.aws_region
  default_tags { tags = local.common_tags }
}
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags { tags = local.common_tags }
}

# CloudFront viewer certificate must live in us-east-1 AND must cover the exact
# alias (api.<env_domain>). A wildcard covers only ONE label, so the cert domain
# is derived from env_domain (never hardcoded):
#   prod     env_domain=zordnet.com          -> alias api.zordnet.com          -> cert *.zordnet.com
#   staging  env_domain=staging.zordnet.com  -> alias api.staging.zordnet.com  -> cert *.staging.zordnet.com
#   dev      env_domain=dev.zordnet.com      -> alias api.dev.zordnet.com      -> cert *.dev.zordnet.com
# So the ACM lookup domain is exactly env_domain (its *.env_domain wildcard cert).
data "aws_acm_certificate" "wildcard_us_east_1" {
  count       = local.edge_active ? 1 : 0
  provider    = aws.us_east_1
  domain      = local.config.dns.env_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  # ── Origin is the STABLE Kong hostname, not the live ALB DNS name ──
  # CloudFront points at api.<env_domain> (e.g. api.staging.zordnet.com). External
  # DNS makes that hostname resolve to the shared ALB once Kong is synced in the
  # ArgoCD UI. Because the origin is a fixed hostname (not a runtime-discovered ALB
  # ARN), Terraform can create CloudFront on the first apply with ZERO wait. Until
  # Kong is up, CloudFront simply returns errors; the moment Kong is healthy and DNS
  # resolves, it serves traffic automatically — no re-apply, no bootstrap.
  #
  # A per-env override (edge.kong_alb_domain_name) is still honored if ever set.
  origin_host = local.config.edge.kong_alb_domain_name != "" ? local.config.edge.kong_alb_domain_name : "${local.config.edge.subdomain}.${local.config.dns.env_domain}"

  edge_active = local.config.edge.enabled
}

module "edge" {
  source              = "../../../stacks/06-edge"
  providers           = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  environment         = local.config.environment
  domain              = local.config.dns.env_domain
  subdomain           = local.config.edge.subdomain
  origin_domain_name  = local.edge_active ? local.origin_host : ""
  waf_rate_limit      = local.config.edge.waf_rate_limit
  acm_certificate_arn = local.edge_active ? data.aws_acm_certificate.wildcard_us_east_1[0].arn : ""
}

output "enabled" { value = module.edge.enabled }
output "cloudfront_domain_name" { value = module.edge.cloudfront_domain_name }
output "cloudfront_distribution_id" { value = module.edge.cloudfront_distribution_id }
output "cloudfront_hosted_zone_id" { value = module.edge.cloudfront_hosted_zone_id }
output "public_fqdn" { value = module.edge.public_fqdn }
output "waf_web_acl_arn" { value = module.edge.waf_web_acl_arn }
output "origin_verify_header_name" { value = module.edge.origin_verify_header_name }
output "origin_verify_secret" {
  value     = module.edge.origin_verify_secret
  sensitive = true
}
