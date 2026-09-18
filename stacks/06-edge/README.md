# 06 Edge composition

Reusable Terraform composition for the CloudFront and AWS WAF edge layer. It contains no backend or provider configuration; the calling root module must supply both the default AWS provider and an `aws.us_east_1` alias.

## Included module

- `../../modules/aws-cloudfront-waf`

The composition forwards the default AWS provider to regional resources and the `aws.us_east_1` provider to the global-scope WAF resources. CloudFront certificates must also be issued in `us-east-1`.

## Usage

Configure both AWS provider instances in the calling root module, then pass them to this composition:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "edge" {
  source = "../../../stacks/06-edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment         = "production"
  domain              = "example.com"
  subdomain           = "api"
  origin_domain_name  = "example-alb.ap-south-1.elb.amazonaws.com"
  waf_rate_limit      = 2000
  acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
}
```

Set `origin_domain_name` to an empty string to keep CloudFront and WAF disabled until the origin exists.

## Outputs

The composition exposes whether the edge layer is enabled, the CloudFront domain name, distribution ID and hosted zone ID, the public FQDN, the WAF Web ACL ARN, and the origin verification header name and secret. The origin verification secret output is marked sensitive.
