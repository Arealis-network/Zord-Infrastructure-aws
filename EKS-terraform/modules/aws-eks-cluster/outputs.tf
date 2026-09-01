# ═══════════════════════════════════════════════════════════════════
# EKS Cluster — Outputs
# ═══════════════════════════════════════════════════════════════════

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

output "cluster_role_arn" {
  description = "IAM role ARN used by the EKS cluster."
  value       = aws_iam_role.cluster_role.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL."
  value       = aws_iam_openid_connect_provider.eks.url
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group (attached to nodes/pods). Used to lock RDS ingress to the cluster."
  value       = aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id
}
