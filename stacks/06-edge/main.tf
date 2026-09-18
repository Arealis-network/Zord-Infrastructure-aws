terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

module "cloudfront_waf" {
  source = "../../modules/aws-cloudfront-waf"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment         = var.environment
  domain              = var.domain
  subdomain           = var.subdomain
  origin_domain_name  = var.origin_domain_name
  waf_rate_limit      = var.waf_rate_limit
  acm_certificate_arn = var.acm_certificate_arn
}
