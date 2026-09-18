output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded EKS cluster CA certificate."
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "EKS OIDC provider URL."
  value       = module.eks.oidc_provider_url
}

output "stateful_node_group_name" {
  description = "Stateful managed node group name."
  value       = module.node_groups.stateful_node_group_name
}

output "stateless_node_group_name" {
  description = "Stateless managed node group name."
  value       = module.node_groups.stateless_node_group_name
}

output "stateful_node_group_id" {
  description = "Stateful managed node group ID."
  value       = module.node_groups.stateful_node_group_id
}

output "stateless_node_group_id" {
  description = "Stateless managed node group ID."
  value       = module.node_groups.stateless_node_group_id
}

output "worker_role_arn" {
  description = "IAM role ARN attached to EKS worker nodes."
  value       = module.node_groups.worker_role_arn
}

output "pod_identity_addon_id" {
  description = "EKS Pod Identity Agent addon ID."
  value       = module.addons.pod_identity_addon_id
}

output "bastion_public_ip" {
  description = "Static public IP of the EC2 admin bastion."
  value       = module.ec2_admin.ec2_public_ip
}

output "bastion_instance_id" {
  description = "EC2 admin bastion instance ID."
  value       = module.ec2_admin.instance_id
}

output "admin_role_arn" {
  description = "IAM role ARN used by the EC2 admin bastion."
  value       = module.ec2_admin.ec2_admin_role_arn
}
