############################
# cluster outputs
############################

output "environment" {
  description = "Deployment environment (staging or production)."
  value       = var.environment
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = aws_eks_cluster.eks.endpoint
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.eks.arn
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
  value       = aws_vpc.eks_vpc.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value = [
    aws_subnet.public1.id,
    aws_subnet.public2.id
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value = [
    aws_subnet.private1.id,
    aws_subnet.private2.id
  ]
}

############################
# node group outputs
############################

output "stateful_node_group_name" {
  description = "Stateful (on-demand) node group name."
  value       = aws_eks_node_group.stateful.node_group_name
}

output "stateless_node_group_name" {
  description = "Stateless (spot) node group name."
  value       = aws_eks_node_group.stateless.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN attached to the EKS worker nodes."
  value       = aws_iam_role.worker_role.arn
}

############################
# ec2 output
############################

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance created in the public subnet."
  value       = aws_instance.eks.public_ip
}

############################
# storage addon output
############################

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver."
  value       = aws_iam_role.ebs_csi_role.arn
}

############################
# cluster autoscaler output
############################

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by the Cluster Autoscaler."
  value       = aws_iam_role.cluster_autoscaler_role.arn
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator."
  value       = aws_iam_role.external_secrets_role.arn
}

############################
# oidc output
############################

output "oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL for the EKS cluster."
  value       = aws_iam_openid_connect_provider.eks.url
}

############################
# ses output
############################

output "ses_domain" {
  description = "SES domain identity."
  value       = aws_ses_domain_identity.this.domain
}

output "ses_verification_token" {
  description = "TXT record value for SES domain verification."
  value       = aws_ses_domain_identity.this.verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM CNAME tokens for SES."
  value       = aws_ses_domain_dkim.this.dkim_tokens
}

output "ses_send_role_arn" {
  description = "IAM role ARN used by workload pods to send SES emails."
  value       = aws_iam_role.ses_send_role.arn
}
