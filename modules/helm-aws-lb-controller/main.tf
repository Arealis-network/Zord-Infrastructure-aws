# ═══════════════════════════════════════════════════════════════════
# AWS Load Balancer Controller — turns Ingress/Service objects into
# real AWS ALBs/NLBs. This is what creates the single shared ALB
# (group.name: zord-shared-alb) that fronts Kong + ArgoCD.
# Self-contained: IAM Policy + Role + Pod Identity + Helm.
# ═══════════════════════════════════════════════════════════════════

resource "aws_iam_policy" "lb_controller" {
  name        = "${var.eks_resource_prefix}-lb-controller-policy"
  description = "AWS Load Balancer Controller permissions (create/manage ALB/NLB)."
  policy      = file("${path.module}/iam-policy.json")

  tags = {
    Name = "${var.eks_name_prefix} lb controller policy"
  }
}

resource "aws_iam_role" "lb_controller" {
  name = "${var.eks_resource_prefix}-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} lb controller role"
  }
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn

  depends_on = [
    aws_iam_role_policy_attachment.lb_controller,
    var.pod_identity_addon_ready
  ]
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # Disable the Service mutating webhook. We expose everything via Ingress (ALB),
  # NOT Service type=LoadBalancer, so we don't need it. Leaving it on makes the
  # webhook intercept EVERY Service creation cluster-wide — and while the controller
  # pods are still starting, that blocks other charts (e.g. External Secrets) with
  # "no endpoints available for aws-load-balancer-webhook-service". Off = no race.
  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }

  depends_on = [
    aws_eks_pod_identity_association.lb_controller,
    var.node_groups_ready
  ]
}
