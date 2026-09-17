output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.eks_vpc.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [aws_subnet.public1.id, aws_subnet.public2.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = [aws_subnet.private1.id, aws_subnet.private2.id]
}

output "public_subnet_1_id" {
  description = "Public subnet 1 ID."
  value       = aws_subnet.public1.id
}

output "security_group_id" {
  description = "Allow-all security group ID."
  value       = aws_security_group.allow_all.id
}
