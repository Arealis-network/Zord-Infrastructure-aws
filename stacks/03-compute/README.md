# Compute composition

Reusable Terraform composition for the EKS control plane, managed node groups, core AWS-managed EKS addons, and an EC2 admin bastion.

This composition deliberately does not configure a Terraform backend or any providers. The calling root module must configure the AWS and TLS providers. It also deliberately excludes `aws-ebs-csi`; that module uses the Kubernetes provider and belongs in the platform layer.

## Included modules

- `../../modules/aws-eks-cluster`
- `../../modules/aws-eks-node-groups`
- `../../modules/aws-eks-addons`
- `../../modules/aws-ec2-admin`

It also creates standalone ingress rules allowing the bastion security group to reach the EKS API on TCP/443 and the EKS cluster security group to reach PostgreSQL on TCP/5432.

## Usage

```hcl
module "compute" {
  source = "./stacks/03-compute"

  environment                       = "production"
  aws_region                        = "us-east-1"
  cluster_name                      = "zord-production"
  eks_name_prefix                   = "Zord production"
  eks_resource_prefix               = "zord-production"
  node_group_name                   = "zord-production"
  cluster_version                   = "1.31"
  private_subnet_ids                = module.network.private_subnet_ids
  public_subnet_1_id                = module.network.public_subnet_1_id
  vpc_security_group_id             = module.network.security_group_id
  rds_security_group_id             = module.database.rds_security_group_id
  admin_principal_arn               = "arn:aws:iam::123456789012:role/platform-admin"
  manage_cluster_admin_access_entry = true
  endpoint_public_access            = true
  public_access_cidrs                = ["203.0.113.10/32"]
  ami_id                             = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  account_id                        = data.aws_caller_identity.current.account_id
}
```

The caller should pass provider configurations normally; no `providers` map is needed when using default AWS and TLS provider instances.
