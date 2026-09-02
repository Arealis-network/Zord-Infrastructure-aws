############################
# cluster outputs
############################

output "environment" {
  description = "Deployment environment (staging or production)."
  value       = var.environment
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_admin_principal_arn" {
  description = "IAM principal ARN that Terraform grants EKS cluster admin access to."
  value       = local.admin_principal_arn
}

############################
# network outputs
############################

output "vpc_id" {
  description = "VPC ID used by the EKS cluster."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

############################
# node group outputs
############################

output "stateful_node_group_name" {
  description = "Stateful (on-demand) node group name."
  value       = module.node_groups.stateful_node_group_name
}

output "stateless_node_group_name" {
  description = "Stateless (spot) node group name."
  value       = module.node_groups.stateless_node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN attached to the EKS worker nodes."
  value       = module.node_groups.worker_role_arn
}

############################
# ec2 output
############################

output "ec2_public_ip" {
  description = "Static public IP (Elastic IP) of the EC2 admin instance."
  value       = module.ec2_admin.ec2_public_ip
}

############################
# storage addon output
############################

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver."
  value       = module.ebs_csi.role_arn
}

############################
# cluster autoscaler output
############################

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by the Cluster Autoscaler."
  value       = module.cluster_autoscaler.role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator."
  value       = module.external_secrets.role_arn
}

############################
# oidc output
############################

output "oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL for the EKS cluster."
  value       = module.eks.oidc_provider_url
}

############################
# ses output
############################

output "ses_domain" {
  description = "SES domain identity."
  value       = module.ses.ses_domain
}

output "ses_verification_token" {
  description = "TXT record value for SES domain verification."
  value       = module.ses.ses_verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM CNAME tokens for SES."
  value       = module.ses.ses_dkim_tokens
}

output "ses_send_role_arn" {
  description = "IAM role ARN used by workload pods to send SES emails."
  value       = module.ses.ses_send_role_arn
}

############################
# kms output
############################

output "s3_kms_key_arn" {
  description = "KMS key ARN used for S3 bucket encryption."
  value       = module.kms.s3_kms_key_arn
}

output "s3_kms_key_id" {
  description = "KMS key ID used for S3 bucket encryption."
  value       = module.kms.s3_kms_key_id
}

############################
# s3 output
############################

output "s3_bucket_names" {
  description = "Map of bucket keys to bucket names."
  value       = module.s3_buckets.bucket_names
}

output "s3_access_role_arn" {
  description = "Map of per-service S3 IAM role ARNs (PLAT-07 least privilege)."
  value       = module.s3_access.role_arns
}

############################
# acm output
############################

output "acm_certificate_arn" {
  description = "ACM wildcard certificate ARN (auto-fetched from AWS)."
  value       = data.aws_acm_certificate.wildcard.arn
}

# Explicitly-named alias requested by the app/K8s team so ingress values reference
# ONE known infra output instead of hardcoding the cert ARN (avoids drift on rotation).
output "wildcard_acm_certificate_arn" {
  description = "Wildcard (*.zordnet.com) ACM cert ARN for app ingress annotations. Use this in Grafana/Kong/observability ingresses instead of hardcoding."
  value       = data.aws_acm_certificate.wildcard.arn
}

############################
# shared ALB group names (for app-team ingress annotations)
############################

output "shared_alb_group_api" {
  description = "ALB ingress group.name for public APIs (Kong). Set alb.ingress.kubernetes.io/group.name to this."
  value       = var.kong_alb_stack_tag
}

output "shared_alb_group_observability" {
  description = "ALB ingress group.name for dashboards (Grafana, ArgoCD UI, Kibana). Set alb.ingress.kubernetes.io/group.name to this."
  value       = var.argocd_alb_group
}

############################
# token enclave output
############################

output "token_enclave_kms_key_arn" {
  description = "KMS key ARN for zord-token-enclave PII encryption."
  value       = module.kms_token_enclave.kms_key_arn
}

output "token_enclave_role_arn" {
  description = "IAM role ARN for zord-token-enclave KMS access."
  value       = module.kms_token_enclave.role_arn
}

############################
# evidence archive kms output
############################

output "evidence_kms_key_arn" {
  description = "KMS key ARN for evidence archive encryption (NEW-P1-06)."
  value       = module.kms_evidence_archive.kms_key_arn
}

############################
# cloudfront + waf output (edge layer)
############################

output "cloudfront_enabled" {
  description = "Whether the CloudFront/WAF edge layer is active."
  value       = module.cloudfront_waf.enabled
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name. Point api.<domain> DNS CNAME at this."
  value       = module.cloudfront_waf.cloudfront_domain_name
}

output "cloudfront_public_fqdn" {
  description = "Public entrypoint FQDN served by CloudFront (e.g. api.zordnet.com)."
  value       = module.cloudfront_waf.public_fqdn
}

output "cloudfront_waf_web_acl_arn" {
  description = "ARN of the WAF WebACL attached to CloudFront."
  value       = module.cloudfront_waf.waf_web_acl_arn
}

output "cloudfront_origin_verify_header" {
  description = "Header name CloudFront injects for origin cloaking (Kong/ALB must require it)."
  value       = module.cloudfront_waf.origin_verify_header_name
}

output "cloudfront_origin_verify_secret" {
  description = "Secret value for the origin-verify header. Give to app team. Sensitive — read via: terraform output -raw cloudfront_origin_verify_secret"
  value       = module.cloudfront_waf.origin_verify_secret
  sensitive   = true
}



############################
# rds postgres output
############################

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (DB_HOST). All services connect here."
  value       = module.rds_postgres.endpoint
}

output "rds_instance_id" {
  description = "RDS instance identifier."
  value       = module.rds_postgres.instance_id
}

output "rds_connection_secret" {
  description = "Secrets Manager secret holding RDS endpoint + master creds."
  value       = "${var.environment}/zord/db-connection"
}
