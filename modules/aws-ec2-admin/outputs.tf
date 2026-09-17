output "ec2_public_ip" {
  description = "Static public IP (Elastic IP) of the EC2 admin instance."
  value       = aws_eip.admin.public_ip
}

output "ec2_admin_role_arn" {
  description = "IAM role ARN for the EC2 admin instance."
  value       = aws_iam_role.ec2_admin_role.arn
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.eks.id
}
