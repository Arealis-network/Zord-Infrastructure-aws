# ═══════════════════════════════════════════════════════════════════
# CloudFront + WAF — MNC edge layer (caching, DDoS, WAF)
#
# Traffic flow:
#   Internet
#     ↓
#   CloudFront (this module) — caching, DDoS (AWS Shield Standard), WAF
#     ↓
#   Shared internet-facing ALB (created by AWS LB Controller in the app repo)
#     ↓
#   Kong (Ingress + API Gateway, ClusterIP behind the ALB)
#     ↓
#   Microservices
#
# Self-contained: WAF WebACL + CloudFront distribution + association.
# CloudFront + its WAF are GLOBAL — WAF WebACL MUST live in us-east-1
# and the ACM cert for the alias MUST also be in us-east-1.
#
# NOTE (confirmed with app team): Kong is NOT exposed via an NLB. It sits
# behind a shared internet-facing ALB (group zord-shared-alb) that already
# terminates TLS with the ap-south-1 *.zordnet.com cert. CloudFront's origin
# therefore points at the ALB DNS name. The custom origin below talks HTTPS
# to the ALB and forwards the Host header (api.zordnet.com), which matches
# the ALB's *.zordnet.com cert so SNI/TLS validation succeeds.
#
# The whole module is gated on origin_domain_name being set. The ALB is
# created at runtime by the app repo, so on the very first apply this is
# empty and CloudFront/WAF are skipped. Once the K8s team gives you the
# ALB DNS name, set it and re-apply to bring the edge layer up.
# ═══════════════════════════════════════════════════════════════════

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  enabled     = var.origin_domain_name != ""
  fqdn        = "${var.subdomain}.${var.domain}"
  name_prefix = "arealis-zord-${var.environment == "production" ? "prod" : "stg"}"
  origin_id   = "kong-alb-origin"
}

# ─────────────────────────────────────────
# Origin cloaking secret — CloudFront injects this header on every request
# to the ALB. The app team configures Kong/ALB to REJECT any request that
# does not carry it. This prevents attackers from bypassing CloudFront (and
# therefore WAF) by hitting the ALB DNS name directly. #1 fintech edge control.
# ─────────────────────────────────────────

resource "random_password" "origin_secret" {
  count   = local.enabled ? 1 : 0
  length  = 40
  special = false
}

# FULLY AUTOMATIC: the secret is written to AWS Secrets Manager. Kong reads it
# via External Secrets Operator (no manual copy). No ignore_changes here — this
# value is Terraform-owned and must stay in sync with CloudFront.
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

  # ── CANONICAL CONTRACT (locked with app team — do not rename) ──
  # These JSON keys become the K8s Secret keys (app team uses dataFrom: extract).
  # Kong pod env reads CLOUDFRONT_ORIGIN_VERIFY_SECRET. App repo files that depend
  # on these exact names: deployment.yaml, configmap.yaml, CLOUDFRONT-EDGE.md.
  secret_string = jsonencode({
    CLOUDFRONT_ORIGIN_VERIFY_HEADER = "X-Origin-Verify"
    CLOUDFRONT_ORIGIN_VERIFY_SECRET = random_password.origin_secret[0].result
  })
}

# ─────────────────────────────────────────
# WAF WebACL (scope = CLOUDFRONT, must be us-east-1)
# AWS managed rule sets + IP rate limiting.
# ─────────────────────────────────────────

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

  # Bot Control — detects and blocks scrapers, scanners, automated abuse.
  # Fintech-relevant: stops credential stuffing / automated fraud probing.
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

# ─────────────────────────────────────────
# WAF observability — metrics only (no CloudWatch Logs, to avoid log ingestion cost).
#
# WAF cannot push to Prometheus (it is a managed edge service with no scrape
# endpoint). But every rule's visibility_config emits CloudWatch METRICS
# (blocked/allowed/matched counts) — these are near-zero cost, unlike CloudWatch
# LOGS. View them in Grafana via the CloudWatch data source.
#
# The per-request CloudWatch Logs group was intentionally removed to eliminate
# log-ingestion cost. If request-level WAF forensics are ever required (e.g. for
# a compliance audit), re-add an aws_wafv2_web_acl_logging_configuration pointing
# at CloudWatch Logs, S3, or Kinesis Firehose (WAF's only supported destinations).
# ─────────────────────────────────────────

# ─────────────────────────────────────────
# Security response headers policy (HSTS, anti-clickjacking, etc.)
# Applied to every response CloudFront returns.
# ─────────────────────────────────────────

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

# ─────────────────────────────────────────
# CloudFront distribution — fronts the shared ALB (Kong)
# ─────────────────────────────────────────

resource "aws_cloudfront_distribution" "edge" {
  count = local.enabled ? 1 : 0

  enabled         = true
  comment         = "${local.name_prefix} edge Internet to CloudFront to shared ALB to Kong"
  aliases         = [local.fqdn]
  is_ipv6_enabled = true
  web_acl_id      = aws_wafv2_web_acl.edge[0].arn
  price_class     = "PriceClass_200" # NA + EU + Asia (covers India)

  # Origin = shared internet-facing ALB fronting Kong. HTTPS-only to the ALB;
  # the forwarded Host header (api.zordnet.com) matches the ALB's *.zordnet.com
  # cert so origin TLS validation succeeds.
  origin {
    domain_name = var.origin_domain_name
    origin_id   = local.origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Origin cloaking: secret header on every origin request. Kong/ALB must
    # reject requests missing it, so nobody can bypass CloudFront/WAF by
    # hitting the ALB directly.
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
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security[0].id

    # API traffic: forward everything, do not cache by default.
    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
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
