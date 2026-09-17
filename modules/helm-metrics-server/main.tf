# ═══════════════════════════════════════════════════════════════════
# Metrics Server — cluster-wide resource metrics (metrics.k8s.io)
#
# Required for Horizontal Pod Autoscalers (HPA) and `kubectl top`. Without it
# every HPA reports targets as <unknown> and cannot scale (e.g. kong-gateway
# HPA showing cpu:<unknown>/70%). Scrapes kubelet summary API only — needs NO
# AWS IAM (no Pod Identity), so this module is just the Helm release.
#
# Official chart: https://kubernetes-sigs.github.io/metrics-server/
# ═══════════════════════════════════════════════════════════════════

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.chart_version
  namespace  = "kube-system"

  # Sensible defaults for EKS. Secure kubelet TLS: EKS kubelet serving certs are
  # not signed by a CA metrics-server trusts by default, so allow insecure TLS to
  # the kubelet (standard, documented EKS setting). Traffic is node-local.
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }

  # Small footprint — metrics-server is lightweight.
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # HA-friendly: keep it available during node churn.
  set {
    name  = "replicas"
    value = "1"
  }

  depends_on = [var.node_groups_ready]
}
