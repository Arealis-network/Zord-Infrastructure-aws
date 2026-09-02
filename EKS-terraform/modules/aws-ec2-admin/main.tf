############################
# EC2 IAM ACCESS
############################

resource "aws_iam_role" "ec2_admin_role" {
  name = "${var.eks_resource_prefix}-ec2-admin-role"

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
    Name = "${var.eks_name_prefix} ec2 admin role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_eks_access" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# SEC H1: ECR pull-only (was AmazonEC2ContainerRegistryFullAccess).
resource "aws_iam_role_policy_attachment" "ec2_ecr_access" {
  role       = aws_iam_role.ec2_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SEC H1: scoped S3 access to the zord-* buckets only (was AmazonS3FullAccess,
# which granted read/write/delete on EVERY bucket in the account).
resource "aws_iam_role_policy" "ec2_s3_scoped" {
  name = "${var.eks_resource_prefix}-ec2-s3-scoped"
  role = aws_iam_role.ec2_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::zord-*",
          "arn:aws:s3:::zord-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_eks_describe" {
  name = "${var.eks_resource_prefix}-ec2-eks-describe"
  role = aws_iam_role.ec2_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:ListAddons",
          "eks:DescribeAddon",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
      # Read-only access to THIS project's secrets so the bastion can fetch
      # ArgoCD/observability credentials. Scoped to production/zord/* only.
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = ["arn:aws:secretsmanager:*:*:secret:production/zord/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_admin_profile" {
  name = "${var.eks_resource_prefix}-ec2-admin-profile"
  role = aws_iam_role.ec2_admin_role.name

  tags = {
    Name = "${var.eks_name_prefix} ec2 admin profile"
  }
}

############################
# EKS ACCESS FOR EC2 ROLE
############################

resource "aws_eks_access_entry" "ec2_admin_role" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.ec2_admin_role.arn
  type          = "STANDARD"

  tags = {
    Name = "${var.eks_name_prefix} ec2 admin access entry"
  }
}

resource "aws_eks_access_policy_association" "ec2_admin_role" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.ec2_admin_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.ec2_admin_role
  ]
}

############################
# EC2 INSTANCE
############################

resource "aws_instance" "eks" {
  ami                    = var.ami_id
  instance_type          = "t3.large"
  subnet_id              = var.public_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_admin_profile.name
  vpc_security_group_ids = [var.security_group_id]

  # SEC M1: enforce IMDSv2 (token required) + hop limit 1 to block SSRF-based
  # credential theft from the instance metadata service.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = "60"
    encrypted   = true
  }

  tags = {
    Name = "${var.eks_name_prefix} admin instance"
  }

  user_data = file("${path.module}/tool.sh")

  lifecycle {
    ignore_changes = [user_data, ami]
  }
}

############################
# EC2 ELASTIC IP (static)
############################

resource "aws_eip" "admin" {
  domain = "vpc"

  tags = {
    Name = "${var.eks_name_prefix} admin eip"
  }
}

resource "aws_eip_association" "admin" {
  instance_id   = aws_instance.eks.id
  allocation_id = aws_eip.admin.id
}

############################
# EC2 AUTO-STOP SCHEDULE
############################

resource "aws_scheduler_schedule" "ec2_stop" {
  name       = "${var.eks_resource_prefix}-ec2-stop-night"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  # Stop at 7:30 PM IST, Monday–Saturday. No stop on Sunday (already stopped from Sat night).
  schedule_expression          = "cron(30 19 ? * MON-SAT *)"
  schedule_expression_timezone = "Asia/Kolkata"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      InstanceIds = [aws_instance.eks.id]
    })
  }
}

resource "aws_scheduler_schedule" "ec2_start" {
  name       = "${var.eks_resource_prefix}-ec2-start-morning"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  # Start at 9:30 AM IST, Monday–Saturday. No start on Sunday (stays off all Sunday, 24h).
  schedule_expression          = "cron(30 9 ? * MON-SAT *)"
  schedule_expression_timezone = "Asia/Kolkata"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      InstanceIds = [aws_instance.eks.id]
    })
  }
}

resource "aws_iam_role" "scheduler_role" {
  name = "${var.eks_resource_prefix}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} scheduler role"
  }
}

resource "aws_iam_role_policy" "scheduler_ec2" {
  name = "${var.eks_resource_prefix}-scheduler-ec2-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:StartInstances",
        "ec2:StopInstances"
      ]
      Resource = aws_instance.eks.arn
    }]
  })
}
