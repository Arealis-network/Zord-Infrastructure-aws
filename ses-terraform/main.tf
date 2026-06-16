terraform {
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  env_short       = var.environment == "production" ? "prod" : "stg"
  resource_prefix = "arealis-zord-${local.env_short}"
  cluster_name    = var.eks_cluster_name != "" ? var.eks_cluster_name : "arealis-zord-${local.env_short}-eks"

  common_tags = {
    Environment = var.environment
    Project     = "arealis-zord-ses"
    Owner       = "yaswanth"
    ManagedBy   = "Terraform"
  }
}

############################
# SES DOMAIN IDENTITY
############################

resource "aws_ses_domain_identity" "this" {
  domain = var.ses_domain
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

resource "aws_ses_domain_mail_from" "this" {
  domain           = aws_ses_domain_identity.this.domain
  mail_from_domain = "mail.${var.ses_domain}"
}

############################
# SES EMAIL IDENTITIES
############################

resource "aws_ses_email_identity" "support" {
  email = "support@${var.ses_domain}"
}

resource "aws_ses_email_identity" "no_reply" {
  email = "no-reply@${var.ses_domain}"
}

############################
# IAM - SES SEND ROLE
############################

resource "aws_iam_policy" "ses_send" {

  name        = "${local.resource_prefix}-ses-send-policy"
  description = "Allows workload pods to send emails via SES for OTP MFA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = [
          "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/${var.ses_domain}",
          "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/support@${var.ses_domain}",
          "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/no-reply@${var.ses_domain}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:GetSendQuota",
          "ses:GetSendStatistics"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${local.resource_prefix} ses send policy"
  }
}

resource "aws_iam_role" "ses_send_role" {

  name = "${local.resource_prefix}-ses-send-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = {
    Name = "${local.resource_prefix} ses send role"
  }
}

resource "aws_iam_role_policy_attachment" "ses_send" {

  role       = aws_iam_role.ses_send_role.name
  policy_arn = aws_iam_policy.ses_send.arn
}

############################
# POD IDENTITY ASSOCIATION
############################

resource "aws_eks_pod_identity_association" "ses_send" {
  cluster_name    = local.cluster_name
  namespace       = var.workload_namespace
  service_account = var.workload_service_account

  role_arn = aws_iam_role.ses_send_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.ses_send
  ]
}
