locals {
  external_secret_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.environment}/zord/*"
  ]
}

module "s3_access" {
  source = "../../modules/aws-s3-access"

  cluster_name        = var.cluster_name
  eks_name_prefix     = var.eks_name_prefix
  eks_resource_prefix = var.eks_resource_prefix
  namespace           = "zord"
  kms_key_arn         = var.s3_kms_key_arn

  edge_bucket_arn       = var.edge_bucket_arn
  canonical_bucket_arn  = var.canonical_bucket_arn
  nir_bucket_arn        = var.nir_bucket_arn
  governance_bucket_arn = var.governance_bucket_arn
  outcome_bucket_arn    = var.outcome_bucket_arn
  evidence_bucket_arn   = var.evidence_bucket_arn
  pod_identity_addon_id = var.pod_identity_addon_id
}

module "secrets_manager" {
  source = "../../modules/aws-secrets-manager"

  environment               = var.environment
  s3_kms_key_arn            = var.s3_kms_key_arn
  acm_certificate_arn       = var.acm_certificate_arn
  evidence_kms_key_arn      = var.evidence_kms_key_arn
  token_enclave_kms_key_arn = var.token_enclave_kms_key_arn

  edge_bucket_name       = var.edge_bucket_name
  canonical_bucket_name  = var.canonical_bucket_name
  nir_bucket_name        = var.nir_bucket_name
  governance_bucket_name = var.governance_bucket_name
  outcome_bucket_name    = var.outcome_bucket_name
  evidence_bucket_name   = var.evidence_bucket_name
}

module "ses_email" {
  source = "../../modules/aws-ses-email"

  eks_name_prefix              = var.eks_name_prefix
  eks_resource_prefix          = var.eks_resource_prefix
  cluster_name                 = var.cluster_name
  aws_region                   = var.aws_region
  account_id                   = var.account_id
  ses_domain                   = var.ses_domain
  manage_domain_identity       = var.manage_ses_domain_identity
  ses_workload_namespace       = var.ses_workload_namespace
  ses_workload_service_account = var.ses_workload_service_account
  pod_identity_addon_id        = var.pod_identity_addon_id
}
resource "aws_iam_role_policy" "evidence_archive_kms" {
  name = "${var.eks_resource_prefix}-evidence-archive-kms-policy"
  role = module.s3_access.evidence_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EvidenceArchiveKMS"
      Effect = "Allow"
      Action = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      Resource = [var.evidence_kms_key_arn]
    }]
  })
}

resource "aws_eks_pod_identity_association" "token_enclave" {
  cluster_name    = var.cluster_name
  namespace       = "zord"
  service_account = "zord-token-enclave"
  role_arn        = var.token_enclave_role_arn
}

resource "aws_resourcegroups_group" "zord" {
  name        = "${var.eks_resource_prefix}-resources"
  description = "Arealis Zord ${var.environment} project resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = ["arealis-zord-eks"]
        },
        {
          Key    = "Environment"
          Values = [var.environment]
        }
      ]
    })
  }

  tags = {
    Name        = "${var.eks_name_prefix} resource group"
    Project     = "arealis-zord-eks"
    Environment = var.environment
  }
}
