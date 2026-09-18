# ═══════════════════════════════════════════════════════════════════
# ArgoCD Applications — FINAL 5-Application-per-environment model.
#
# The app team delivered the umbrella chart kubernetes/charts/zord-app,
# so zord-platform-<env> is now ONE Application bundling platform + all
# 10 services (console, edge, evidence, intelligence, intent-engine,
# ml-service, outcome-engine, prompt-layer, relay, token-enclave).
#
# 5 Applications per environment:
#   zord-platform-<env>  chart=zord-app     values=app.yaml         ns=zord         MANUAL
#   kong-gateway-<env>   chart=kong-gateway values=kong.yaml        ns=api-gateway  MANUAL
#   zord-logging-<env>   chart=zord-logging values=logging.yaml     ns=logging      AUTO
#   zord-monitoring-<env> chart=zord-monitoring values=monitoring.yaml ns=monitoring AUTO + ServerSideApply
#   zord-tracing-<env>   chart=zord-tracing values=tracing.yaml     ns=tracing      AUTO (retry: depends on ES + Prometheus)
#
# application_mode = "legacy" keeps the original manifest-path Applications
# (production migration safety) until staging + dev pass E2E.
# ═══════════════════════════════════════════════════════════════════

locals {
  app_sync_options = ["CreateNamespace=true", "ApplyOutOfSyncOnly=true"]

  # Retry so tracing survives Elasticsearch/Prometheus not being ready yet.
  app_retry = {
    limit   = 10
    backoff = { duration = "10s", factor = 2, maxDuration = "3m" }
  }

  # Auto-sync policy for observability (logging/monitoring/tracing).
  app_auto_sync_policy = {
    automated   = { prune = true, selfHeal = true }
    retry       = local.app_retry
    syncOptions = local.app_sync_options
  }

  # Manual policy for platform + kong: NEVER auto-sync, even when
  # applications_auto_sync = true. Operator syncs these by hand.
  app_manual_sync_policy = {
    retry       = local.app_retry
    syncOptions = local.app_sync_options
  }

  # The five Applications. auto = whether this app auto-syncs; ssa = ServerSideApply.
  helm_application_specs = {
    platform = {
      app = "zord-platform", chart = "zord-app", file = "app.yaml", release = "zord-platform", namespace = "zord", auto = false, ssa = false
    }
    kong = {
      app = "kong-gateway", chart = "kong-gateway", file = "kong.yaml", release = "kong-gateway", namespace = "api-gateway", auto = false, ssa = false
    }
    logging = {
      app = "zord-logging", chart = "zord-logging", file = "logging.yaml", release = "zord-logging", namespace = "logging", auto = true, ssa = false
    }
    monitoring = {
      app = "zord-monitoring", chart = "zord-monitoring", file = "monitoring.yaml", release = "zord-monitoring", namespace = "monitoring", auto = true, ssa = true
    }
    tracing = {
      app = "zord-tracing", chart = "zord-tracing", file = "tracing.yaml", release = "zord-tracing", namespace = "tracing", auto = true, ssa = false
    }
  }
}

locals {
  helm_applications = {
    for key, spec in local.helm_application_specs : "${spec.app}-${var.application_name_suffix}" => {
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
      project    = "default"
      sources = [
        {
          repoURL        = var.app_repo_url
          targetRevision = var.app_target_revision
          path           = "kubernetes/charts/${spec.chart}"
          helm = {
            releaseName = spec.release
            valueFiles  = ["$values/kubernetes/values/${var.values_environment}/${spec.file}"]
          }
        },
        { repoURL = var.app_repo_url, targetRevision = var.app_target_revision, ref = "values" }
      ]
      destination = { server = "https://kubernetes.default.svc", namespace = spec.namespace }

      # platform + kong stay MANUAL always; observability auto-syncs only when enabled.
      syncPolicy = (spec.auto && var.applications_auto_sync ? (
        spec.ssa ? merge(local.app_auto_sync_policy, { syncOptions = concat(local.app_sync_options, ["ServerSideApply=true"]) }) : local.app_auto_sync_policy
        ) : (
        spec.ssa ? merge(local.app_manual_sync_policy, { syncOptions = concat(local.app_sync_options, ["ServerSideApply=true"]) }) : local.app_manual_sync_policy
      ))
    }
  }

  legacy_applications = {
    zord-platform = {
      namespace   = "argocd", finalizers = ["resources-finalizer.argocd.argoproj.io"], project = "default"
      source      = { repoURL = var.app_repo_url, targetRevision = var.app_target_revision, path = "kubernetes/eks" }
      destination = { server = "https://kubernetes.default.svc", namespace = "zord" }
      syncPolicy  = { syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "PruneLast=true", "ApplyOutOfSyncOnly=true"] }
    }
    kong-api-gateway = {
      namespace   = "argocd", finalizers = ["resources-finalizer.argocd.argoproj.io"], project = "default"
      source      = { repoURL = var.app_repo_url, targetRevision = var.app_target_revision, path = "kubernetes/api-gateway" }
      destination = { server = "https://kubernetes.default.svc", namespace = "api-gateway" }
      syncPolicy  = { syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "ApplyOutOfSyncOnly=true"] }
    }
    logging = {
      namespace   = "argocd", finalizers = ["resources-finalizer.argocd.argoproj.io"], project = "default"
      source      = { repoURL = var.app_repo_url, targetRevision = var.app_target_revision, path = "kubernetes/logging" }
      destination = { server = "https://kubernetes.default.svc", namespace = "logging" }
      syncPolicy  = { syncOptions = ["CreateNamespace=true", "PrunePropagationPolicy=foreground", "ApplyOutOfSyncOnly=true"] }
    }
    monitoring = {
      namespace   = "argocd", finalizers = ["resources-finalizer.argocd.argoproj.io"], project = "default"
      source      = { repoURL = var.app_repo_url, targetRevision = var.app_target_revision, path = "kubernetes/monitoring" }
      destination = { server = "https://kubernetes.default.svc", namespace = "monitoring" }
      syncPolicy  = { syncOptions = ["CreateNamespace=true", "ServerSideApply=true"] }
    }
    tracing = {
      namespace   = "argocd", finalizers = ["resources-finalizer.argocd.argoproj.io"], project = "default"
      source      = { repoURL = var.app_repo_url, targetRevision = var.app_target_revision, path = "kubernetes/tracing" }
      destination = { server = "https://kubernetes.default.svc", namespace = "tracing" }
      syncPolicy  = { syncOptions = ["CreateNamespace=true", "ApplyOutOfSyncOnly=true"] }
    }
  }

  applications = var.application_mode == "helm" ? local.helm_applications : local.legacy_applications
}

resource "helm_release" "argocd_apps" {
  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.apps_chart_version
  namespace  = "argocd"
  values     = [yamlencode({ applications = local.applications })]
  depends_on = [helm_release.argocd]
}
