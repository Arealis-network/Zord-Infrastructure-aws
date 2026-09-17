# ═══════════════════════════════════════════════════════════════════
# External DNS — auto-creates/updates Route53 records from Ingress hosts.
# ArgoCD (argocd.zordnet.com), Kong (api.zordnet.com), and any future
# ingress get their DNS record created automatically. No manual Route53.
# Self-contained: IAM Policy + Role + Pod Identity + Helm.
# Domain-filtered to the project's zone so it only touches these records.
# ═══════════════════════════════════════════════════════════════════

resource "aws_iam_policy" "external_dns" {
  name        = "${var.eks_resource_prefix}-external-dns-policy"
  description = "External DNS — manage Route53 records in the project hosted zone."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = {
    Name = "${var.eks_name_prefix} external dns policy"
  }
}

resource "aws_iam_role" "external_dns" {
  name = "${var.eks_resource_prefix}-external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} external dns role"
  }
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns.arn

  depends_on = [
    aws_iam_role_policy_attachment.external_dns,
    var.pod_identity_addon_ready
  ]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version
  namespace  = "kube-system"

  set {
    name  = "provider.name"
    value = "aws"
  }

  # sync: create/update AND delete records so a destroy removes OUR records cleanly.
  # Safe on the shared zone because of txtOwnerId below — External DNS only deletes
  # records carrying ITS OWN TXT owner stamp. Other teams' records (demo, mail, www)
  # have no matching stamp and are NEVER touched.
  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  set {
    name  = "domainFilters[0]"
    value = var.domain
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  # Only manage records from Ingress objects (the shared ALB hosts).
  # Not "service" — avoids creating records for every LoadBalancer svc in the cluster.
  set {
    name  = "sources[0]"
    value = "ingress"
  }

  depends_on = [
    aws_eks_pod_identity_association.external_dns,
    var.node_groups_ready
  ]
}
