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

# CloudFront viewer cert (us-east-1). Look up the apex; one *.zordnet.com cert serves all envs.
data "aws_acm_certificate" "edge_us_east_1" {
  count       = local.edge_active ? 1 : 0
  provider    = aws.us_east_1
  domain      = local.config.dns.ses_domain
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  # Public hosts -> CloudFront. Single label per env: prod api/www, staging stg-api/stg-www, dev dev-api/dev-www.
  host_prefix       = local.config.environment == "production" ? "" : "${local.env_short}-"
  public_subdomains = [for s in local.config.edge.public_subdomains : "${local.host_prefix}${s}"]
  public_fqdns      = [for s in local.public_subdomains : "${s}.${local.config.dns.ses_domain}"]

  # Primary (api) host: used for public_url.
  primary_subdomain = "${local.host_prefix}${local.config.edge.subdomain}"
  primary_fqdn      = "${local.primary_subdomain}.${local.config.dns.ses_domain}"

  # Origin = a separate stable host (e.g. stg-origin-api) that External DNS auto-points at the ALB.
  # Kept different from the public names so CloudFront's origin never loops back on itself.
  origin_subdomain = "${local.host_prefix}${local.config.edge.origin_subdomain}"
  origin_host      = local.config.edge.kong_alb_domain_name != "" ? local.config.edge.kong_alb_domain_name : "${local.origin_subdomain}.${local.config.dns.ses_domain}"

  # Edge comes up on the first apply, even before the ALB exists.
  edge_active = local.config.edge.enabled
}

# Apex zone. Infra owns the public records; External DNS owns only the origin record.
data "aws_route53_zone" "apex" {
  count        = local.edge_active ? 1 : 0
  name         = "${local.config.dns.ses_domain}."
  private_zone = false
}

# Public hosts -> CloudFront (A + AAAA per host). Created automatically by apply.
resource "aws_route53_record" "public_ipv4" {
  for_each = local.edge_active ? toset(local.public_fqdns) : []
  zone_id  = data.aws_route53_zone.apex[0].zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = module.edge.cloudfront_domain_name
    zone_id                = module.edge.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "public_ipv6" {
  for_each = local.edge_active ? toset(local.public_fqdns) : []
  zone_id  = data.aws_route53_zone.apex[0].zone_id
  name     = each.value
  type     = "AAAA"

  alias {
    name                   = module.edge.cloudfront_domain_name
    zone_id                = module.edge.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

module "edge" {
  source              = "../../../stacks/06-edge"
  providers           = { aws = aws, aws.us_east_1 = aws.us_east_1 }
  environment         = local.config.environment
  domain              = local.config.dns.ses_domain
  subdomain           = local.primary_subdomain
  public_fqdns        = local.public_fqdns
  origin_domain_name  = local.edge_active ? local.origin_host : ""
  waf_rate_limit      = local.config.edge.waf_rate_limit
  acm_certificate_arn = local.edge_active ? data.aws_acm_certificate.edge_us_east_1[0].arn : ""
}

output "enabled" { value = module.edge.enabled }
output "cloudfront_domain_name" { value = module.edge.cloudfront_domain_name }
output "cloudfront_distribution_id" { value = module.edge.cloudfront_distribution_id }
output "cloudfront_hosted_zone_id" { value = module.edge.cloudfront_hosted_zone_id }
output "public_fqdn" { value = module.edge.public_fqdn }
output "waf_web_acl_arn" { value = module.edge.waf_web_acl_arn }

# Primary API URL (via CloudFront).
output "public_url" { value = local.edge_active ? "https://${local.primary_fqdn}" : "" }

# All public hosts (api/www/kong-admin), all via CloudFront.
output "public_fqdns" { value = local.public_fqdns }

# Origin host the app team's External DNS must point at the ALB. Internal only.
output "origin_fqdn" { value = local.edge_active ? local.origin_host : "" }
output "origin_verify_header_name" { value = module.edge.origin_verify_header_name }
output "origin_verify_secret" {
  value     = module.edge.origin_verify_secret
  sensitive = true
}
