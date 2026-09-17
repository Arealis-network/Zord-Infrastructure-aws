##########################################################################
# Outputs consumed by later components via terraform_remote_state.
# Treat these as a public contract - renaming one breaks a downstream component.
##########################################################################

output "vpc_id" {
  description = "VPC ID."
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

output "public_subnet_1_id" {
  description = "First public subnet (bastion lives here)."
  value       = module.vpc.public_subnet_1_id
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDRs (RDS ingress is restricted to these)."
  value       = [local.private1_cidr, local.private2_cidr]
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = local.vpc_cidr
}

output "s3_kms_key_arn" {
  description = "KMS key ARN for S3 and RDS encryption."
  value       = module.kms.s3_kms_key_arn
}

output "s3_kms_key_id" {
  description = "KMS key ID for S3 encryption."
  value       = module.kms.s3_kms_key_id
}

output "cluster_name" {
  description = "Cluster name this environment will use (naming contract)."
  value       = local.cluster_name
}

output "env_domain" {
  description = "DNS zone for this environment."
  value       = local.env_domain
}
