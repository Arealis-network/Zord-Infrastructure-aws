# ═══════════════════════════════════════════════════════════════════
# External Secrets Operator — Syncs AWS Secrets Manager → K8s Secrets
# EKS Pod Identity grants SecretsManager access (no IMDS needed)
# Infra owns: IAM Role + Pod Identity + ESO Helm controller.
# App team owns: the ClusterSecretStore CR (via ArgoCD) — see note below.
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# IAM Role for External Secrets (EKS Pod Identity)
# EKS Pod Identity — pods get AWS creds via service account binding
# ─────────────────────────────────────────

resource "aws_iam_role" "external_secrets" {
  name = "${var.eks_resource_prefix}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} external secrets role"
  }
}

# SecretsManager permissions — read secrets for the operator
resource "aws_iam_role_policy" "external_secrets_sm" {
  name = "${var.eks_resource_prefix}-external-secrets-sm-policy"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets",
        "secretsmanager:GetResourcePolicy",
      ]
      Resource = var.secret_arns
    }]
  })
}

# ─────────────────────────────────────────
# EKS Pod Identity Association
# Binds IAM role → external-secrets service account
# ─────────────────────────────────────────

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [aws_iam_role_policy.external_secrets_sm]
}

# ─────────────────────────────────────────
# External Secrets Operator Helm Release
# ─────────────────────────────────────────

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = var.namespace
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = var.service_account
    }
  })]

  depends_on = [
    aws_eks_pod_identity_association.external_secrets,
    var.node_groups_ready
  ]
}


resource "time_sleep" "wait_for_eso_crds" {
  depends_on      = [helm_release.external_secrets]
  create_duration = "30s"
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = var.cluster_secret_store_name
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          # Region is driven by the environment, never hardcoded.
          region = var.aws_region
          # Pod Identity: the ESO controller's service account is bound to the IAM
          # role above, so no static credentials and no IRSA annotation needed.
          auth = {}
        }
      }
    }
  }

  depends_on = [
    time_sleep.wait_for_eso_crds,
    aws_eks_pod_identity_association.external_secrets,
  ]
}
