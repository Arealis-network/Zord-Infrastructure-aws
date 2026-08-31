############################
# VPC
############################

resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name_prefix
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "${var.vpc_name_prefix} igw"
  }
}

############################
# SUBNETS
############################

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public1_cidr
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.vpc_name_prefix} public subnet 1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = var.public2_cidr
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.vpc_name_prefix} public subnet 2"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private1_cidr
  availability_zone = var.availability_zones[0]

  tags = {
    Name                              = "${var.vpc_name_prefix} private subnet 1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.private2_cidr
  availability_zone = var.availability_zones[1]

  tags = {
    Name                              = "${var.vpc_name_prefix} private subnet 2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

############################
# NAT GATEWAY
############################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name_prefix} nat eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "${var.vpc_name_prefix} nat gateway"
  }
}

############################
# ROUTE TABLES
############################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.vpc_name_prefix} public route table"
  }
}

resource "aws_route_table_association" "pub1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pub2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.vpc_name_prefix} private route table"
  }
}

resource "aws_route_table_association" "priv1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "priv2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

############################
# SECURITY GROUP
############################

resource "aws_security_group" "allow_all" {
  name        = "${var.vpc_resource_prefix}-admin-sg"
  description = "Admin EC2 security group - restricted ports"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 7777
    to_port     = 7777
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 7771
    to_port     = 7771
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name_prefix} admin sg"
  }
}

############################
# VPC ENDPOINTS (PLAT-09 — S3 traffic stays inside VPC)
############################

# S3 Gateway Endpoint — free, routes S3 traffic through AWS private network
# Pods no longer need 0.0.0.0/0:443 for S3 access
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.eks_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = [
    aws_route_table.private.id,
    aws_route_table.public.id
  ]

  tags = {
    Name = "${var.vpc_name_prefix} s3 endpoint"
  }
}
