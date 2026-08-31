# ═══════════════════════════════════════════════════════════════════
# Argo Rollouts — Canary + Blue/Green deployment controller
# Enables progressive delivery (canary %, traffic shifting, auto-rollback)
# Self-contained: Namespace + Helm Release
# ═══════════════════════════════════════════════════════════════════

resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true

  values = [yamlencode({
    dashboard = {
      enabled = true
    }
  })]

  depends_on = [var.node_groups_ready]
}
