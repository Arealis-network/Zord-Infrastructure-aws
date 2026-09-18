# 05 Platform composition

Reusable Terraform composition for Kubernetes platform services on the Arealis Zord EKS cluster. It contains no backend or provider blocks; the calling root module must configure and pass the AWS, Helm, Kubernetes, and Random providers.

## Components

- EBS CSI driver and default `gp3` StorageClass.
- Cluster Autoscaler and Metrics Server.
- AWS Load Balancer Controller and External DNS.
- External Secrets Operator.
- Argo Rollouts and Argo CD, including the configured application repository.

All child modules are sourced from `../../modules/`. EBS CSI is intentionally in this stack because it manages Kubernetes resources in addition to its AWS addon and IAM resources.

## Usage

```hcl
module "platform" {
  source = "../../../stacks/05-platform"

  environment         = var.environment
  aws_region          = var.aws_region
  cluster_name        = data.terraform_remote_state.compute.outputs.cluster_name
  vpc_id              = data.terraform_remote_state.foundation.outputs.vpc_id
  eks_name_prefix     = local.eks_name_prefix
  eks_resource_prefix = local.eks_resource_prefix

  node_groups_ready        = data.terraform_remote_state.compute.outputs.node_groups_ready
  pod_identity_addon_ready = data.terraform_remote_state.compute.outputs.pod_identity_addon_id

  env_domain          = var.env_domain
  acm_certificate_arn = data.terraform_remote_state.foundation.outputs.acm_certificate_arn
  secret_arns         = data.terraform_remote_state.security.outputs.external_secret_arns

  external_secrets_namespace       = "external-secrets"
  external_secrets_service_account = "external-secrets"
  github_pat                      = var.github_pat
  app_repo_url                    = var.app_repo_url
  argocd_alb_group                = "zord-shared-alb"
}
```

`github_pat` is sensitive and should be supplied through a secure variable mechanism. The stack exposes release statuses where child modules provide them, platform IAM role ARNs, and Argo CD access details.
