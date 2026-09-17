output "bucket_arns" {
  description = "Map of bucket key to ARN."
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "bucket_names" {
  description = "Map of bucket key to name."
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "all_bucket_arns" {
  description = "List of all bucket ARNs (for IAM policies)."
  value       = [for b in aws_s3_bucket.this : b.arn]
}
