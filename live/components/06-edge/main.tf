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

# CloudFront viewer certificate must live in us-east-1. ONE apex wildcard cert
# (*.<ses_domain>, e.g. *.zordnet.com) is shared by ALL environments, because
# every env's public host is a single label under the apex (api./stg-api./dev-api.).
# The lookup uses the apex ses_domain, matching that one shared cert.
data "aws_acm_certificate" "wildcard_us_east_1" {
  count       = local.edge_active ? 1 : 0
  provider    = aws.us_east_1
  domain      = local.config.dns.ses_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  # ── ONE apex wildcard cert (*.<ses_domain>) for ALL environments ──
  # A wildcard covers only ONE label, so every env's public host is a single
  # label under the apex (never api.staging.<apex>, which needs a 2nd cert):
  #   prod     -> api.zordnet.com
  #   staging  -> stg-api.zordnet.com
  #   dev      -> dev-api.zordnet.com
  # All three are *.zordnet.com, covered by the single us-east-1 cert.
  public_subdomain = local.config.environment == "production" ? local.config.edge.subdomain : "${local.env_short}-${local.config.edge.subdomain}"

  # ── Origin is the STABLE Kong hostname, not the live ALB DNS name ──
  # CloudFront points at the public host above. External DNS makes it resolve to
  # the shared ALB once Kong is synced. Fixed hostname (not a discovered ALB ARN),
  # so CloudFront is created on the first apply with ZERO wait; it serves traffic
  # automatically the moment Kong is healthy. A per-env override
  # (edge.kong_alb_domain_name) is still honored if ever set.
  origin_host = local.config.edge.kong_alb_domain_name != "" ? local.config.edge.kong_alb_domain_name : "${local.public_subdomain}.${local.config.dns.ses_domain}"

  edge_active = local.config.edge.enabled
}

module "edge" {
  source              = "../../../stacks/06-edge"
  providers           = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  environment         = local.config.environment
  domain              = local.config.dns.ses_domain
  subdomain           = local.public_subdomain
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
