# ═══════════════════════════════════════════════════════════════════
# EKS Node Groups — Stateful (on-demand) + Stateless (spot)
# Self-contained: owns the worker IAM role + policy attachments
# ═══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────
# IAM Role — Worker Nodes
# ─────────────────────────────────────────

resource "aws_iam_role" "worker_role" {
  name = "${var.eks_resource_prefix}-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} worker role"
  }
}

resource "aws_iam_role_policy_attachment" "worker_node" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "worker_alb" {
  role       = aws_iam_role.worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# ─────────────────────────────────────────
# Node Group — Stateful (on-demand)
# ─────────────────────────────────────────

resource "aws_launch_template" "stateful" {
  name_prefix            = "${var.node_group_name}-stateful-"
  update_default_version = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # SEC H6: encrypt node root EBS volume at rest.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 40
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.eks_name_prefix} stateful node"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.eks_name_prefix} stateful node volume"
    }
  }

  tags = {
    Name = "${var.eks_name_prefix} stateful launch template"
  }
}

resource "aws_eks_node_group" "stateful" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.node_group_name}-stateful"

  node_role_arn = aws_iam_role.worker_role.arn
  version       = var.cluster_version

  subnet_ids = var.private_subnet_ids

  instance_types = ["t3.xlarge"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  labels = {
    workload = "stateful"
  }

  taint {
    key    = "workload"
    value  = "stateful"
    effect = "NO_SCHEDULE"
  }

  launch_template {
    id      = aws_launch_template.stateful.id
    version = aws_launch_template.stateful.latest_version
  }

  tags = {
    Name = "${var.eks_name_prefix} stateful node group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_iam_role_policy_attachment.cni,
    aws_iam_role_policy_attachment.ecr,
  ]
}

# ─────────────────────────────────────────
# Node Group — Stateless (spot)
# ─────────────────────────────────────────

resource "aws_launch_template" "stateless" {
  name_prefix            = "${var.node_group_name}-stateless-"
  update_default_version = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # SEC H6: encrypt node root EBS volume at rest.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 40
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.eks_name_prefix} stateless node"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.eks_name_prefix} stateless node volume"
    }
  }

  tags = {
    Name = "${var.eks_name_prefix} stateless launch template"
  }
}

resource "aws_eks_node_group" "stateless" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.node_group_name}-stateless"

  node_role_arn = aws_iam_role.worker_role.arn
  version       = var.cluster_version

  subnet_ids = var.private_subnet_ids

  instance_types = ["t3.large", "t3.xlarge", "m5.large"]
  capacity_type  = "SPOT"

  scaling_config {
    desired_size = 4
    max_size     = 20
    min_size     = 1
  }

  labels = {
    workload = "stateless"
  }

  launch_template {
    id      = aws_launch_template.stateless.id
    version = aws_launch_template.stateless.latest_version
  }

  tags = {
    Name = "${var.eks_name_prefix} stateless node group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node,
    aws_iam_role_policy_attachment.cni,
    aws_iam_role_policy_attachment.ecr,
  ]
}

# ─────────────────────────────────────────
# ASG Tags
# ─────────────────────────────────────────

resource "aws_autoscaling_group_tag" "stateful_instance_name" {
  autoscaling_group_name = aws_eks_node_group.stateful.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "Name"
    value               = "${var.eks_name_prefix} stateful node"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group_tag" "stateful_autoscaler_owned" {
  autoscaling_group_name = aws_eks_node_group.stateful.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "stateful_autoscaler_enabled" {
  autoscaling_group_name = aws_eks_node_group.stateful.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "stateless_instance_name" {
  autoscaling_group_name = aws_eks_node_group.stateless.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "Name"
    value               = "${var.eks_name_prefix} stateless node"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group_tag" "stateless_autoscaler_owned" {
  autoscaling_group_name = aws_eks_node_group.stateless.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_group_tag" "stateless_autoscaler_enabled" {
  autoscaling_group_name = aws_eks_node_group.stateless.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}
