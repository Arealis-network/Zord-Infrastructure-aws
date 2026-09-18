terraform {
  required_version = ">= 1.11.0"
  backend "s3" {}
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    helm       = { source = "hashicorp/helm", version = "~> 2.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
    random     = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = local.config.aws_region
  default_tags { tags = local.common_tags }
}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.foundation, region = local.config.aws_region }
}
data "terraform_remote_state" "compute" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.compute, region = local.config.aws_region }
}
data "terraform_remote_state" "security" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = local.state_keys.security, region = local.config.aws_region }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.compute.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.config.cluster_name, "--region", local.config.aws_region]
    }
  }
}
provider "kubernetes" {
  host                   = data.terraform_remote_state.compute.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.config.cluster_name, "--region", local.config.aws_region]
  }
}

module "platform" {
  source                           = "../../../stacks/05-platform"
  environment                      = local.config.environment
  aws_region                       = local.config.aws_region
  cluster_name                     = local.config.cluster_name
  vpc_id                           = data.terraform_remote_state.foundation.outputs.vpc_id
  eks_name_prefix                  = local.config.eks_name_prefix
  eks_resource_prefix              = local.config.eks_resource_prefix
  node_groups_ready                = data.terraform_remote_state.compute.outputs.stateless_node_group_id
  pod_identity_addon_ready         = data.terraform_remote_state.compute.outputs.pod_identity_addon_id
  env_domain                       = local.config.dns.env_domain
  acm_certificate_arn              = data.terraform_remote_state.security.outputs.acm_certificate_arn
  secret_arns                      = data.terraform_remote_state.security.outputs.external_secret_arns
  external_secrets_namespace       = local.config.platform.external_secrets_namespace
  external_secrets_service_account = local.config.platform.external_secrets_service_account
  github_pat                       = var.github_pat
  app_repo_url                     = local.config.platform.app_repo_url
  argocd_alb_group                 = local.config.dns.argocd_alb_group
  application_mode                 = local.config.platform.application_mode
  app_target_revision              = local.config.platform.target_revision
  values_environment               = local.config.platform.values_environment
  applications_auto_sync           = local.config.platform.applications_auto_sync
  application_name_suffix          = local.config.platform.application_name_suffix
}

output "ebs_csi_role_arn" { value = module.platform.ebs_csi_role_arn }
output "cluster_autoscaler_role_arn" { value = module.platform.cluster_autoscaler_role_arn }
output "external_secrets_role_arn" { value = module.platform.external_secrets_role_arn }
output "argocd_url" { value = module.platform.argocd_url }
output "argocd_credentials_secret_name" { value = module.platform.argocd_credentials_secret_name }
output "platform_ready" { value = module.platform.platform_ready }
