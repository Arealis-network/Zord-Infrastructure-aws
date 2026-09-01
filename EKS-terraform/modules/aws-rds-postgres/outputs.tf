output "endpoint" {
  description = "RDS endpoint hostname (DB_HOST). App points all services here."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS port."
  value       = aws_db_instance.this.port
}

output "instance_id" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.rds.id
}

output "master_username" {
  description = "RDS master username."
  value       = var.master_username
}
