# ═══════════════════════════════════════════════════════════════════
# ArgoCD — GitOps continuous delivery for Kubernetes
# Watches Git repos and auto-syncs K8s manifests to cluster
# Self-contained: Namespace + Helm Release + Admin credentials in Secrets Manager
# Access via: argocd.zordnet.com (ALB Ingress)
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# Random admin password
# ─────────────────────────────────────────

resource "random_password" "argocd_admin" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ─────────────────────────────────────────
# Store credentials in AWS Secrets Manager (separate secret)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "argocd_credentials" {
  name                    = "${var.environment}/zord/argocd-credentials"
  description             = "ArgoCD admin login credentials (${var.environment})"
  recovery_window_in_days = 0

  tags = {
    Name    = "${var.environment}/zord/argocd-credentials"
    Service = "argocd"
  }
}

resource "aws_secretsmanager_secret_version" "argocd_credentials" {
  secret_id = aws_secretsmanager_secret.argocd_credentials.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.argocd_admin.result
    url      = "https://argocd.${var.domain}"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ─────────────────────────────────────────
# ArgoCD Helm Release
# ─────────────────────────────────────────

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  values = [yamlencode({
    server = {
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class"                    = "alb"
          "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"          = "ip"
          "alb.ingress.kubernetes.io/certificate-arn"      = var.acm_certificate_arn
          "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/backend-protocol"     = "HTTPS"
          "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTPS"
          "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz"
        }
        hosts = ["argocd.${var.domain}"]
        tls = [{
          hosts = ["argocd.${var.domain}"]
        }]
      }
    }
    configs = {
      secret = {
        argocdServerAdminPassword = bcrypt(random_password.argocd_admin.result)
      }
    }
  })]

  depends_on = [var.node_groups_ready]
}

# ─────────────────────────────────────────
# ArgoCD Git Repo Secret (for private repo access)
# Created automatically — no manual kubectl needed
# ─────────────────────────────────────────

resource "kubernetes_secret" "argocd_repo" {
  metadata {
    name      = "argocd-repo-arealis-zord"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = "https://github.com/Arealis-network/Arealis-Zord-intent.git"
    username = var.github_username
    password = var.github_pat
  }

  depends_on = [helm_release.argocd]
}
