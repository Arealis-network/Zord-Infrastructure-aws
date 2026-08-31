output "enabled" {
  description = "Whether the CloudFront/WAF edge layer is active (true once origin_domain_name is set)."
  value       = local.enabled
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name. Point your DNS (api.<domain>) CNAME at this."
  value       = local.enabled ? aws_cloudfront_distribution.edge[0].domain_name : ""
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = local.enabled ? aws_cloudfront_distribution.edge[0].id : ""
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID (for Route53 alias records)."
  value       = local.enabled ? aws_cloudfront_distribution.edge[0].hosted_zone_id : ""
}

output "public_fqdn" {
  description = "Public entrypoint FQDN served by CloudFront."
  value       = local.fqdn
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL attached to CloudFront."
  value       = local.enabled ? aws_wafv2_web_acl.edge[0].arn : ""
}

output "waf_log_group" {
  description = "CloudWatch log group holding WAF request logs."
  value       = local.enabled ? aws_cloudwatch_log_group.waf[0].name : ""
}

output "origin_verify_header_name" {
  description = "Header name CloudFront injects on every origin request (X-Origin-Verify). Kong requires it. Secret JSON keys: CLOUDFRONT_ORIGIN_VERIFY_HEADER / CLOUDFRONT_ORIGIN_VERIFY_SECRET (Kong reads CLOUDFRONT_ORIGIN_VERIFY_SECRET)."
  value       = local.enabled ? "X-Origin-Verify" : ""
}

output "origin_verify_secret" {
  description = "Secret value for X-Origin-Verify. Give to app team so Kong/ALB rejects requests without it. Sensitive."
  value       = local.enabled ? random_password.origin_secret[0].result : ""
  sensitive   = true
}
