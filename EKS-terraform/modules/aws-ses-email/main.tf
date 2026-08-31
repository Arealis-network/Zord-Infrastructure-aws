############################
# SES EMAIL (OTP MFA)
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

resource "aws_ses_email_identity" "support" {
  email = "support@${var.ses_domain}"
}

resource "aws_ses_email_identity" "no_reply" {
  email = "no-reply@${var.ses_domain}"
}

############################
# SES IAM ROLE
############################

resource "aws_iam_policy" "ses_send" {
  name        = "${var.eks_resource_prefix}-ses-send-policy"
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
          "arn:aws:ses:${var.aws_region}:${var.account_id}:identity/${var.ses_domain}",
          "arn:aws:ses:${var.aws_region}:${var.account_id}:identity/support@${var.ses_domain}",
          "arn:aws:ses:${var.aws_region}:${var.account_id}:identity/no-reply@${var.ses_domain}"
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
    Name = "${var.eks_name_prefix} ses send policy"
  }
}

resource "aws_iam_role" "ses_send_role" {
  name = "${var.eks_resource_prefix}-ses-send-role"

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
    Name = "${var.eks_name_prefix} ses send role"
  }
}

resource "aws_iam_role_policy_attachment" "ses_send" {
  role       = aws_iam_role.ses_send_role.name
  policy_arn = aws_iam_policy.ses_send.arn
}

############################
# SES POD IDENTITY
############################

# The pod_identity_addon_id variable creates an implicit dependency ensuring
# the pod identity addon is installed before this association is created.

resource "aws_eks_pod_identity_association" "ses_send" {
  cluster_name    = var.cluster_name
  namespace       = var.ses_workload_namespace
  service_account = var.ses_workload_service_account
  role_arn        = aws_iam_role.ses_send_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.ses_send
  ]
}
