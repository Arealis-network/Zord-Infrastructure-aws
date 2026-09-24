# CloudFront + WAF edge layer. Flow: Internet -> CloudFront/WAF -> ALB -> Kong -> services.
# WAF WebACL and the viewer cert are global, so both must be in us-east-1.
# Gated on origin_domain_name: empty = skipped, set = edge comes up.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# AWS-managed CloudFront policies. CachingDisabled = never cache (API traffic).
# AllViewerExceptHostHeader = forward all viewer headers/query/cookies to the origin
# EXCEPT Host, so CloudFront uses the origin's own hostname for the TLS handshake.
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

locals {
  enabled = var.origin_domain_name != ""
  fqdn    = "${var.subdomain}.${var.domain}"
  # All public hosts CloudFront serves (deduped/sorted for a stable plan).
  aliases     = distinct(sort(length(var.public_fqdns) > 0 ? var.public_fqdns : [local.fqdn]))
  name_prefix = "arealis-zord-${lookup({ production = "prod", staging = "stg", dev = "dev" }, var.environment, "dev")}"
  origin_id   = "kong-alb-origin"
}

# Origin cloaking secret: CloudFront injects it on every origin request; Kong rejects
# requests without it, so nobody can bypass CloudFront/WAF by hitting the ALB directly.
resource "random_password" "origin_secret" {
  count   = local.enabled ? 1 : 0
  length  = 40
  special = false
}

# Written to Secrets Manager; Kong reads it via ESO (no manual copy).
resource "aws_secretsmanager_secret" "origin_verify" {
  count                   = local.enabled ? 1 : 0
  name                    = "${var.environment}/zord/cloudfront-origin-verify"
  description             = "CloudFront origin-cloaking secret. Kong requires this header value to accept traffic (${var.environment})."
  recovery_window_in_days = 0

  tags = {
    Name    = "${var.environment}/zord/cloudfront-origin-verify"
    Service = "cloudfront-waf"
  }
}

resource "aws_secretsmanager_secret_version" "origin_verify" {
  count     = local.enabled ? 1 : 0
  secret_id = aws_secretsmanager_secret.origin_verify[0].id

  # Canonical key names — locked with app team, do not rename (Kong reads them).
  secret_string = jsonencode({
    CLOUDFRONT_ORIGIN_VERIFY_HEADER = "X-Origin-Verify"
    CLOUDFRONT_ORIGIN_VERIFY_SECRET = random_password.origin_secret[0].result
  })
}

# WAF WebACL (scope=CLOUDFRONT, us-east-1): AWS managed rule sets + IP rate limit.
resource "aws_wafv2_web_acl" "edge" {
  count    = local.enabled ? 1 : 0
  provider = aws.us_east_1

  name        = "${local.name_prefix}-edge-waf"
  description = "Edge WAF for CloudFront ${var.environment}"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Common Rule Set — broad protections (bad inputs, common exploits)
  rule {
    name     = "aws-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-aws-common"
      sampled_requests_enabled   = true
    }
  }

  # Known bad inputs
  rule {
    name     = "aws-known-bad-inputs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # SQL injection protection
  rule {
    name     = "aws-sqli"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Bot Control — blocks scrapers/scanners/credential stuffing.
  dynamic "rule" {
    for_each = var.enable_bot_control ? [1] : []
    content {
      name     = "aws-bot-control"
      priority = 5

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesBotControlRuleSet"

          managed_rule_group_configs {
            aws_managed_rules_bot_control_rule_set {
              inspection_level = "COMMON"
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-bot-control"
        sampled_requests_enabled   = true
      }
    }
  }

  # IP rate limiting — blocks abusive clients (DDoS mitigation)
  rule {
    name     = "ip-rate-limit"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-ip-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-edge-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name    = "${local.name_prefix}-edge-waf"
    Service = "cloudfront-waf"
  }
}

# WAF emits CloudWatch metrics (near-zero cost) via each rule's visibility_config.
# Per-request logs are intentionally off; add a logging_configuration if ever needed.

# Security response headers (HSTS, no-sniff, frame-deny, referrer, XSS).
resource "aws_cloudfront_response_headers_policy" "security" {
  count = local.enabled ? 1 : 0

  name = "${local.name_prefix}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000 # 2 years
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

# CloudFront distribution — fronts the shared ALB (Kong).
resource "aws_cloudfront_distribution" "edge" {
  count = local.enabled ? 1 : 0

  enabled         = true
  comment         = "${local.name_prefix} edge Internet to CloudFront to shared ALB to Kong"
  aliases         = local.aliases
  is_ipv6_enabled = true
  web_acl_id      = aws_wafv2_web_acl.edge[0].arn
  price_class     = "PriceClass_200" # NA + EU + Asia (covers India)

  # Origin = shared ALB fronting Kong. HTTPS-only; forwarded Host matches the ALB cert.
  origin {
    domain_name = var.origin_domain_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Origin cloaking header — Kong rejects requests without it.
    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.origin_secret[0].result
    }
  }

  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security[0].id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name    = "${local.name_prefix}-edge-cloudfront"
    Service = "cloudfront-waf"
  }
}
