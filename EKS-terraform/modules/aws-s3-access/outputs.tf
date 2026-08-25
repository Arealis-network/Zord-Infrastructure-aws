# ═══════════════════════════════════════════════════════════════════
# AWS S3 Access — Outputs
# ═══════════════════════════════════════════════════════════════════

output "role_arns" {
  description = "Map of service name to IAM role ARN."
  value       = { for k, v in aws_iam_role.s3_access : k => v.arn }
}

output "edge_role_arn" {
  description = "IAM role ARN for zord-edge S3 access."
  value       = aws_iam_role.s3_access["edge"].arn
}

output "intent_role_arn" {
  description = "IAM role ARN for zord-intent-engine S3 access."
  value       = aws_iam_role.s3_access["intent"].arn
}

output "outcome_role_arn" {
  description = "IAM role ARN for zord-outcome-engine S3 access."
  value       = aws_iam_role.s3_access["outcome"].arn
}

output "evidence_role_arn" {
  description = "IAM role ARN for zord-evidence S3 access."
  value       = aws_iam_role.s3_access["evidence"].arn
}
