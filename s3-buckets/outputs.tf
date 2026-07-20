output "bucket_names" {
  description = "Names of all created S3 buckets."
  value       = { for k, v in aws_s3_bucket.this : k => v.bucket }
}

output "bucket_arns" {
  description = "ARNs of all created S3 buckets."
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}
