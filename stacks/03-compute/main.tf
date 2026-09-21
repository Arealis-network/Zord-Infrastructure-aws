module "eks" {
  source = "../../modules/aws-eks-cluster"

  cluster_name                      = var.cluster_name
  cluster_version                   = var.cluster_version
  private_subnet_ids                = var.private_subnet_ids
  eks_name_prefix                   = var.eks_name_prefix
  eks_resource_prefix               = var.eks_resource_prefix
  admin_principal_arn               = var.admin_principal_arn
  manage_cluster_admin_access_entry = var.manage_cluster_admin_access_entry
  endpoint_public_access            = var.endpoint_public_access
  public_access_cidrs               = var.public_access_cidrs
}

module "node_groups" {
  source = "../../modules/aws-eks-node-groups"

  cluster_name        = module.eks.cluster_name
  cluster_version     = var.cluster_version
  private_subnet_ids  = var.private_subnet_ids
  eks_name_prefix     = var.eks_name_prefix
  eks_resource_prefix = var.eks_resource_prefix
  node_group_name     = var.node_group_name
}

module "addons" {
  source = "../../modules/aws-eks-addons"

  cluster_name            = module.eks.cluster_name
  stateful_node_group_id  = module.node_groups.stateful_node_group_id
  stateless_node_group_id = module.node_groups.stateless_node_group_id

  depends_on = [module.node_groups]
}

module "ec2_admin" {
  source = "../../modules/aws-ec2-admin"

  environment         = var.environment
  eks_name_prefix     = var.eks_name_prefix
  eks_resource_prefix = var.eks_resource_prefix
  cluster_name        = module.eks.cluster_name
  public_subnet_id    = var.public_subnet_1_id
  security_group_id   = var.vpc_security_group_id
  ami_id              = var.ami_id
  account_id          = var.account_id
}

resource "aws_security_group_rule" "bastion_to_eks_api" {
  type                     = "ingress"
  description              = "Allow the admin bastion to reach the EKS API server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = var.vpc_security_group_id
}

resource "aws_security_group_rule" "postgres_from_cluster_sg" {
  type                     = "ingress"
  description              = "Allow the EKS cluster security group to reach PostgreSQL"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = module.eks.cluster_security_group_id
}
