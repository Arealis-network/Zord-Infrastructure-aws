##########################################################################
# Reusable data stack: S3, RDS, evidence and token-enclave KMS resources.
##########################################################################

data "aws_caller_identity" "current" {}

module "s3_buckets" {
  source = "../../modules/aws-s3-buckets"

  environment            = var.environment
  kms_key_arn            = var.s3_kms_key_arn
  force_destroy_buckets  = var.force_destroy_buckets
  edge_bucket_name       = var.edge_bucket_name
  canonical_bucket_name  = var.canonical_bucket_name
  nir_bucket_name        = var.nir_bucket_name
  governance_bucket_name = var.governance_bucket_name
  outcome_bucket_name    = var.outcome_bucket_name
  evidence_bucket_name   = var.evidence_bucket_name
}

module "kms_evidence_archive" {
  source = "../../modules/aws-kms-evidence-archive"

  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  eks_name_prefix     = var.eks_name_prefix
  eks_resource_prefix = var.eks_resource_prefix
  evidence_role_id    = ""
}

module "kms_token_enclave" {
  source = "../../modules/aws-kms-token-enclave"

  environment                     = var.environment
  account_id                      = data.aws_caller_identity.current.account_id
  cluster_name                    = var.cluster_name
  eks_name_prefix                 = var.eks_name_prefix
  eks_resource_prefix             = var.eks_resource_prefix
  create_pod_identity_association = false
  pod_identity_addon_id           = null
}

module "rds_postgres" {
  source = "../../modules/aws-rds-postgres"

  environment               = var.environment
  eks_name_prefix           = var.eks_name_prefix
  eks_resource_prefix       = var.eks_resource_prefix
  vpc_id                    = var.vpc_id
  private_subnet_ids        = var.private_subnet_ids
  private_subnet_cidrs      = var.private_subnet_cidrs
  cluster_security_group_id = ""
  kms_key_arn               = var.s3_kms_key_arn
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage
  multi_az                  = var.rds_multi_az
  engine_version            = var.rds_engine_version
  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = var.rds_skip_final_snapshot
}
