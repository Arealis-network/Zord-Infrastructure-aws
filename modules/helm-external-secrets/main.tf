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


# Wait for the ESO CRDs to be established before creating the custom resource.
resource "time_sleep" "wait_for_eso_crds" {
  depends_on      = [helm_release.external_secrets]
  create_duration = "45s"
}

# IMPLEMENTATION NOTE — why helm_release and not kubernetes_manifest:
#
# kubernetes_manifest requires the target CRD to already exist at PLAN time. On a
# fresh cluster the ESO CRDs do not exist during the first plan, so the plan itself
# would fail with "no such CRD" — breaking any from-scratch deploy. helm_release
# renders at APPLY time (after the CRDs are installed above), so it works on both a
# first apply and re-applies. It also adopts/updates an existing object instead of
# failing with "already exists" if a previous ArgoCD sync left one behind.
resource "helm_release" "cluster_secret_store" {
  name      = "zord-cluster-secret-store"
  namespace = var.namespace
  chart     = "${path.module}/charts/cluster-secret-store"

  set {
    name  = "storeName"
    value = var.cluster_secret_store_name
  }
  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  # Take ownership of the object if it already exists (e.g. created by a previous
  # ArgoCD sync), instead of erroring out.
  force_update  = true
  replace       = false
  recreate_pods = false

  depends_on = [
    time_sleep.wait_for_eso_crds,
    aws_eks_pod_identity_association.external_secrets,
  ]
}
