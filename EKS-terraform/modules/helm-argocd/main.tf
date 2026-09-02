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
          "alb.ingress.kubernetes.io/group.name"  = var.shared_alb_group
          "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
          # Still HTTPS (listen-ports HTTPS:443). No certificate-arn needed — the AWS
          # LB Controller auto-discovers the *.zordnet.com ACM cert by matching the
          # ingress host (argocd.zordnet.com). No ARN anywhere, survives cert rotation.
          "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/backend-protocol"     = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
          "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthz"
          # No plaintext from the internet: force HTTP:80 -> HTTPS:443.
          "alb.ingress.kubernetes.io/ssl-redirect" = "443"
          # Modern TLS only (1.2/1.3) on the public listener.
          "alb.ingress.kubernetes.io/ssl-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        }
        tls = true
      }
    }
    configs = {
      # ArgoCD runs in insecure mode: it serves HTTP internally while the ALB does
      # public TLS. The browser connection stays full HTTPS end-to-public; the only
      # HTTP hop is ALB->pod inside the private VPC (AWS-recommended for ArgoCD+ALB).
      params = {
        "server.insecure" = true
      }
      secret = {
        argocdServerAdminPassword = bcrypt(random_password.argocd_admin.result)
      }
    }
  })]

  depends_on = [var.node_groups_ready]
}

# ─────────────────────────────────────────
# ArgoCD Applications via the dedicated argocd-apps chart.
# This runs AS A SEPARATE helm release AFTER the main argocd install, so the
# Application CRD is already established (fixes the "no matches for kind
# Application / ensure CRDs are installed first" error that extraObjects hit).
# All 5 apps appear on apply. zord/kong/logging/tracing = MANUAL, monitoring = AUTO.
# ─────────────────────────────────────────

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      zord-platform = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = var.app_repo_url
          targetRevision = "main"
          path           = "kubernetes/eks"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "zord"
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "PruneLast=true", "ApplyOutOfSyncOnly=true"]
        }
      }
      kong-api-gateway = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = var.app_repo_url
          targetRevision = "main"
          path           = "kubernetes/api-gateway"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "api-gateway"
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "ApplyOutOfSyncOnly=true"]
        }
      }
      logging = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = var.app_repo_url
          targetRevision = "main"
          path           = "kubernetes/logging"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "logging"
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "ApplyOutOfSyncOnly=true"]
        }
      }
      tracing = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        source = {
          repoURL        = var.app_repo_url
          targetRevision = "main"
          path           = "kubernetes/tracing"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "tracing"
        }
        syncPolicy = {
          syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "ApplyOutOfSyncOnly=true"]
        }
      }
      monitoring = {
        namespace  = "argocd"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        project    = "default"
        sources = [
          {
            repoURL        = "https://prometheus-community.github.io/helm-charts"
            chart          = "kube-prometheus-stack"
            targetRevision = "65.1.1"
            helm = {
              valuesObject = {
                grafana = {
                  ingress = {
                    enabled          = true
                    ingressClassName = "alb"
                    hosts            = ["grafana.${var.domain}"]
                    # Dashboards go on the observability ALB group (this module's
                    # shared_alb_group is already zord-observability - root passes it).
                    # No certificate-arn: LB Controller auto-discovers the wildcard cert.
                    annotations = {
                      "alb.ingress.kubernetes.io/group.name"   = var.shared_alb_group
                      "alb.ingress.kubernetes.io/scheme"       = "internet-facing"
                      "alb.ingress.kubernetes.io/target-type"  = "ip"
                      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]"
                      "alb.ingress.kubernetes.io/ssl-redirect" = "443"
                    }
                  }
                }
                prometheus = {
                  prometheusSpec = {
                    retention                               = "15d"
                    serviceMonitorSelectorNilUsesHelmValues = false
                    storageSpec = {
                      volumeClaimTemplate = {
                        spec = {
                          storageClassName = "gp3"
                          accessModes      = ["ReadWriteOnce"]
                          resources        = { requests = { storage = "20Gi" } }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          {
            repoURL        = var.app_repo_url
            targetRevision = "main"
            path           = "kubernetes/monitoring"
          },
        ]
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "monitoring"
        }
        syncPolicy = {
          automated   = { prune = true, selfHeal = true }
          syncOptions = ["CreateNamespace=true", "ServerSideApply=true"]
        }
      }
    }
  })]

  # Must run AFTER the main argocd release so the Application CRD exists.
  depends_on = [helm_release.argocd]
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
