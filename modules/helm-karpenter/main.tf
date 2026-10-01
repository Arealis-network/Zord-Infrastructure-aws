# ═══════════════════════════════════════════════════════════════════
# Karpenter — just-in-time node provisioning 
#
# Karpenter watches for unschedulable pods and launches the CHEAPEST instance
# that fits them (small when idle, bigger under load), in ~30-60s, then
# consolidates (repacks pods onto fewer nodes and terminates the rest).
#
# Self-contained: controller IAM role (Pod Identity) + node instance profile
# (reuses the existing worker role) + interruption queue + Helm + NodePool/
# EC2NodeClass custom resources.
# ═══════════════════════════════════════════════════════════════════

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ─────────────────────────────────────────
# Controller IAM role (EKS Pod Identity) — lets Karpenter call EC2/pricing/SQS
# ─────────────────────────────────────────

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.eks_resource_prefix}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = { Name = "${var.eks_name_prefix} karpenter controller role" }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name = "${var.eks_resource_prefix}-karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadWrite"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet", "ec2:CreateLaunchTemplate", "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate", "ec2:RunInstances", "ec2:TerminateInstances",
          "ec2:DescribeInstances", "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings", "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeSpotPriceHistory"
        ]
        Resource = "*"
      },
      {
        Sid      = "PricingAndSSM"
        Effect   = "Allow"
        Action   = ["pricing:GetProducts", "ssm:GetParameter"]
        Resource = "*"
      },
      {
        Sid      = "InterruptionQueue"
        Effect   = "Allow"
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid      = "PassNodeRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.worker_role_name}"
      },
      {
        # Karpenter v1 manages the EC2 instance profile for the nodes it launches.
        # Without these, the EC2NodeClass stays "not ready" and the NodePool never
        # becomes ready -> Karpenter logs "no nodepools found" and provisions nothing,
        # leaving pods Pending. (403 AccessDenied on GetInstanceProfile/ListInstanceProfiles.)
        Sid    = "InstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfiles",
          "iam:TagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [aws_iam_role_policy.karpenter_controller, var.pod_identity_addon_ready]
}

# ─────────────────────────────────────────
# Node instance profile — Karpenter-launched nodes assume the EXISTING worker
# role (same permissions as the managed node group), so they join the cluster.
# ─────────────────────────────────────────

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.eks_resource_prefix}-karpenter-node"
  role = var.worker_role_name
  tags = { Name = "${var.eks_name_prefix} karpenter node profile" }
}

# ─────────────────────────────────────────
# Interruption handling — SQS queue Karpenter watches for spot interruption /
# rebalance / instance-terminating events so it can drain gracefully.
# ─────────────────────────────────────────

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.eks_resource_prefix}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = { Name = "${var.eks_name_prefix} karpenter interruption" }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# EventBridge rules that feed interruption events into the queue.
resource "aws_cloudwatch_event_rule" "karpenter" {
  for_each = {
    spot_interrupt = { source = ["aws.ec2"], detail-type = ["EC2 Spot Instance Interruption Warning"] }
    rebalance      = { source = ["aws.ec2"], detail-type = ["EC2 Instance Rebalance Recommendation"] }
    state_change   = { source = ["aws.ec2"], detail-type = ["EC2 Instance State-change Notification"] }
  }
  name          = "${var.eks_resource_prefix}-karpenter-${each.key}"
  event_pattern = jsonencode({ source = each.value.source, "detail-type" = each.value["detail-type"] })
}

resource "aws_cloudwatch_event_target" "karpenter" {
  for_each = aws_cloudwatch_event_rule.karpenter
  rule     = each.value.name
  arn      = aws_sqs_queue.karpenter_interruption.arn
}

# ─────────────────────────────────────────
# Karpenter Helm release (controller)
# ─────────────────────────────────────────

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.chart_version
  namespace        = "kube-system"
  create_namespace = false

  values = [yamlencode({
    serviceAccount = { name = "karpenter" }
    settings = {
      clusterName       = var.cluster_name
      clusterEndpoint   = var.cluster_endpoint
      interruptionQueue = aws_sqs_queue.karpenter_interruption.name
    }
    # Keep the controller itself on the stable node group (not on nodes it manages).
    controller = {
      resources = {
        requests = { cpu = "0.5", memory = "512Mi" }
        limits   = { cpu = "1", memory = "1Gi" }
      }
    }
  })]

  depends_on = [
    aws_eks_pod_identity_association.karpenter,
    var.node_groups_ready
  ]
}

# Wait for Karpenter CRDs (NodePool/EC2NodeClass) to be established before
# creating the custom resources (same pattern as the ESO module).
resource "time_sleep" "wait_for_karpenter_crds" {
  depends_on      = [helm_release.karpenter]
  create_duration = "30s"
}

# ─────────────────────────────────────────
# NodePool + EC2NodeClass — the "small when idle, right-size on load" policy.
# Delivered as a tiny local Helm chart so it renders at APPLY time (CRDs exist
# by then), and adopts/updates an existing object instead of failing.
# ─────────────────────────────────────────

resource "helm_release" "karpenter_nodepool" {
  name      = "karpenter-nodepool"
  namespace = "kube-system"
  chart     = "${path.module}/charts/karpenter-nodepool"

  values = [yamlencode({
    clusterName     = var.cluster_name
    nodeRole        = var.worker_role_name
    instanceProfile = aws_iam_instance_profile.karpenter_node.name
    categories      = var.instance_categories
    sizes           = var.instance_sizes
    capacityTypes   = var.capacity_types
    cpuLimit        = var.cpu_limit
    # Explicit subnet IDs (reliable) instead of tag-guessing; EKS reliably tags
    # only the cluster security group, so SGs still use the cluster tag.
    subnetIds = var.private_subnet_ids
  })]

  force_update  = true
  replace       = false
  recreate_pods = false

  depends_on = [time_sleep.wait_for_karpenter_crds]
}
