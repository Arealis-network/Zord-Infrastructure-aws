output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "public_subnet_1_id" { value = module.vpc.public_subnet_1_id }
output "vpc_security_group_id" { value = module.vpc.security_group_id }
output "s3_kms_key_arn" { value = module.kms.s3_kms_key_arn }
output "s3_kms_key_id" { value = module.kms.s3_kms_key_id }
