output "s3_kms_key_arn" {
  description = "ARN of the KMS key used for S3 bucket encryption."
  value       = aws_kms_key.s3.arn
}

output "s3_kms_key_id" {
  description = "ID of the KMS key used for S3 bucket encryption."
  value       = aws_kms_key.s3.key_id
}

output "s3_kms_alias_arn" {
  description = "ARN of the KMS alias for S3 encryption."
  value       = aws_kms_alias.s3.arn
}
