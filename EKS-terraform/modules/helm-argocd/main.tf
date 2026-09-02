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
  version          = var.chart_version
  namespace        = "argocd"
  create_namespace = true

  values = [yamlencode({
    server = {
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        hostname         = "argocd.${var.domain}"
        annotations = {
          "alb.ingress.kubernetes.io/group.name"      = var.shared_alb_group
          "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"     = "ip"
          "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
          "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
          # End-to-end TLS: ALB terminates public TLS (ACM) and RE-ENCRYPTS to the
          # ArgoCD pod over HTTPS — no plaintext hop, even inside the VPC.
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
          # ArgoCD's API is gRPC (HTTP/2). The ALB must speak HTTP/2 to the backend
          # or the API/login request is terminated. This is the real fix for the
          # "Request has been terminated" error — while staying fully HTTPS.
          "alb.ingress.kubernetes.io/backend-protocol-version" = "GRPC"
          "alb.ingress.kubernetes.io/healthcheck-protocol"     = "HTTPS"
          "alb.ingress.kubernetes.io/healthcheck-path"         = "/healthz"
          # Redirect any HTTP:80 to HTTPS:443 (no plaintext access at all).
          "alb.ingress.kubernetes.io/ssl-redirect" = "443"
          # Enforce modern TLS (TLS 1.2/1.3 only) on the public listener.
          "alb.ingress.kubernetes.io/ssl-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        }
        tls = true
      }
    }
    configs = {
      # ArgoCD server keeps its own TLS ON (secure mode) — HTTPS end to end.
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
