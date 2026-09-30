# ═══════════════════════════════════════════════════════════════════
# External Secrets Operator — Syncs AWS Secrets Manager → K8s Secrets
# EKS Pod Identity grants SecretsManager access (no IMDS needed)
# Infra owns: IAM Role + Pod Identity + ESO Helm controller + the
# ClusterSecretStore CR. The store authenticates with the IAM role created here,
# so it belongs on the infra side. It used to live in the app team's zord-platform
# chart, which is manual and image-gated — that made observability wait on
# unrelated app builds. They removed their copy, so there is a single owner.
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
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  # On destroy the operator's webhook + CR finalizers can block `helm uninstall`
  # until the 5m Helm timeout ("context deadline exceeded"). The null_resource
  # below strips those finalizers first; these settings keep the uninstall itself
  # from waiting on graceful pod/webhook teardown.
  wait          = false
  wait_for_jobs = false

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

# Destroy-time safety net: before the ESO operator is uninstalled, strip
# finalizers from all ESO custom resources and CRDs so nothing blocks teardown.
# This resource depends_on the operator release, so on `terraform destroy` it is
# destroyed FIRST (reverse dependency order) — running the cleanup while the
# operator is still alive, right before its Helm uninstall. No-op on create/apply.
resource "null_resource" "eso_finalizer_cleanup" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    namespace    = var.namespace
  }

  depends_on = [helm_release.external_secrets]

  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set +e
      aws eks update-kubeconfig --name "${self.triggers.cluster_name}" --region "${self.triggers.aws_region}" >/dev/null 2>&1
      # Strip finalizers from ESO custom resources so their deletion doesn't block.
      for kind in clustersecretstores secretstores externalsecrets clusterexternalsecrets pushsecrets; do
        for res in $(kubectl get "$kind" -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {end}' 2>/dev/null); do
          ns="$${res%/*}"; name="$${res#*/}"
          kubectl patch "$kind" -n "$ns" "$name" --type=merge -p '{"metadata":{"finalizers":[]}}' 2>/dev/null
        done
      done
      # Drop the ESO CRDs so the namespace/release can finalize.
      kubectl get crd 2>/dev/null | grep 'external-secrets.io' | awk '{print $1}' | xargs -r kubectl delete crd --wait=false 2>/dev/null
      exit 0
    EOT
  }
}


# Wait for the ESO webhook to be READY before creating the ClusterSecretStore.
# CRDs establish before the webhook pod is serving; creating the CR too early
# fails with "no endpoints available for service external-secrets-webhook".
# Because the operator release runs with wait=false (so destroy doesn't hang),
# we can't rely on Helm's own wait — poll the webhook deployment here instead.
resource "null_resource" "wait_for_eso_webhook" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    namespace    = var.namespace
    # re-run if the operator release changes (e.g. version bump)
    release = helm_release.external_secrets.id
  }

  depends_on = [helm_release.external_secrets]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set +e
      aws eks update-kubeconfig --name "${self.triggers.cluster_name}" --region "${self.triggers.aws_region}" >/dev/null 2>&1
      NS="${self.triggers.namespace}"
      # Wait until the webhook deployment is Available AND its Service has ready
      # endpoints (that's what the admission call actually needs).
      for i in $(seq 1 60); do
        kubectl -n "$NS" rollout status deploy/external-secrets-webhook --timeout=10s >/dev/null 2>&1
        eps=$(kubectl -n "$NS" get endpoints external-secrets-webhook -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$eps" ]; then echo "webhook ready: $eps"; exit 0; fi
        echo "waiting for external-secrets-webhook endpoints... ($i)"; sleep 5
      done
      echo "WARNING: webhook not confirmed ready after ~5m; proceeding anyway"
      exit 0
    EOT
  }
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

  # A '/' in a `set` value is interpreted as a path separator by Helm's --set
  # parser, so the API version is passed through `values` instead.
  values = [yamlencode({
    storeName  = var.cluster_secret_store_name
    awsRegion  = var.aws_region
    apiVersion = var.cluster_secret_store_api_version
  })]

  # Take ownership of the object if it already exists (e.g. created by a previous
  # ArgoCD sync), instead of erroring out.
  force_update  = true
  replace       = false
  recreate_pods = false

  depends_on = [
    null_resource.wait_for_eso_webhook,
    aws_eks_pod_identity_association.external_secrets,
  ]
}
