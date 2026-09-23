output "enabled" {
  description = "Whether the CloudFront and WAF edge layer is active."
  value       = module.cloudfront_waf.enabled
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.cloudfront_waf.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.cloudfront_waf.cloudfront_distribution_id
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route 53 alias records."
  value       = module.cloudfront_waf.cloudfront_hosted_zone_id
}

output "public_fqdn" {
  description = "Primary public entrypoint FQDN served by CloudFront."
  value       = module.cloudfront_waf.public_fqdn
}

output "public_fqdns" {
  description = "All public FQDNs served by CloudFront (api + www)."
  value       = module.cloudfront_waf.public_fqdns
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL attached to CloudFront."
  value       = module.cloudfront_waf.waf_web_acl_arn
}

output "origin_verify_header_name" {
  description = "Header name CloudFront injects into origin requests."
  value       = module.cloudfront_waf.origin_verify_header_name
}

output "origin_verify_secret" {
  description = "Secret value CloudFront injects into the origin verification header."
  value       = module.cloudfront_waf.origin_verify_secret
  sensitive   = true
}
