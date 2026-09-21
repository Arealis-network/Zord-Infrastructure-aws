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
  # ── Sync options (PERMANENT deadlock prevention) ──
  #
  # Without these, a values-only change (e.g. an Ingress host) could never be
  # applied once ANY resource in the Application was unhealthy:
  #   old Ingress host has no matching ACM cert
  #     -> AWS LB Controller refuses to create the ALB
  #        -> Ingress never gets an address, so never becomes "healthy"
  #           -> the sync sits in phase=Running forever waiting on it
  #              -> ArgoCD refuses to start a NEW sync while one is Running
  #                 -> the corrected host is never applied  => permanent deadlock
  #
  # Replace=true      : apply a values change by replacing the object instead of
  #                     patching it, so a new spec lands even mid-degradation.
  # RespectIgnoreDifferences / ApplyOutOfSyncOnly keep syncs minimal.
  # SkipDryRunOnMissingResource avoids stalling on CRDs that are not installed yet.
  #
  # Combined with the FINITE retry limit below, a sync that cannot converge FAILS
  # and releases the operation slot, instead of blocking every future sync.
  # Base options shared by every app (safe with both Replace and ServerSideApply).
  app_sync_options_base = [
    "CreateNamespace=true",
    "ApplyOutOfSyncOnly=true",
    "SkipDryRunOnMissingResource=true",
  ]

  # Default set: base + Replace (for non-SSA apps).
  app_sync_options = concat(local.app_sync_options_base, ["Replace=true"])

  # Finite retry: after these attempts the operation FAILS and frees the slot, so a
  # corrected commit can sync. An unbounded/hanging op is what caused the deadlock.
  app_retry = {
    limit   = 5
    backoff = { duration = "15s", factor = 2, maxDuration = "2m" }
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

      # Every app's syncPolicy has the SAME object shape (automated / retry /
      # syncOptions) so Terraform's type checker is happy.
      #
      # DECLARATIVE auto-sync — no kubectl patching from CI:
      #   platform + kong  -> spec.auto = false  -> automated = null  -> MANUAL forever
      #   observability    -> spec.auto = true   -> automated set when observability_auto_sync
      #
      # Observability uses pinned public images (kube-prometheus-stack, ES/Kibana,
      # Jaeger), so it has no Jenkins image gate and can safely converge by itself
      # the moment the cluster is up. applications_auto_sync is kept for future use
      # but is intentionally NOT required for observability.
      syncPolicy = {
        automated = (spec.auto && (var.observability_auto_sync || var.applications_auto_sync)) ? { prune = true, selfHeal = true } : null
        retry     = local.app_retry
        # Replace=true and ServerSideApply=true are mutually exclusive — SSA apps
        # (kube-prometheus-stack, whose CRDs exceed the annotation limit) must use
        # SSA, so they get the base options + SSA WITHOUT Replace.
        syncOptions = spec.ssa ? concat(local.app_sync_options_base, ["ServerSideApply=true"]) : local.app_sync_options
      }
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

  # Select by map lookup instead of a ternary. The helm and legacy maps have
  # different keys AND different value shapes (sources vs source), so a ?: would
  # fail Terraform's "consistent conditional result types" check. A map index
  # sidesteps that — each branch keeps its own shape.
  applications_by_mode = {
    helm   = local.helm_applications
    legacy = local.legacy_applications
  }
  applications = local.applications_by_mode[var.application_mode]
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
