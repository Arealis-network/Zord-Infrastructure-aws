terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

module "ebs_csi" {
  source = "../../modules/aws-ebs-csi"

  cluster_name             = var.cluster_name
  eks_name_prefix          = var.eks_name_prefix
  eks_resource_prefix      = var.eks_resource_prefix
  pod_identity_addon_ready = var.pod_identity_addon_ready
}

module "cluster_autoscaler" {
  source = "../../modules/helm-cluster-autoscaler"

  cluster_name             = var.cluster_name
  aws_region               = var.aws_region
  eks_name_prefix          = var.eks_name_prefix
  eks_resource_prefix      = var.eks_resource_prefix
  node_groups_ready        = var.node_groups_ready
  pod_identity_addon_ready = var.pod_identity_addon_ready
}

module "metrics_server" {
  source = "../../modules/helm-metrics-server"

  node_groups_ready = var.node_groups_ready
}

module "aws_lb_controller" {
  source = "../../modules/helm-aws-lb-controller"

  cluster_name             = var.cluster_name
  aws_region               = var.aws_region
  vpc_id                   = var.vpc_id
  eks_name_prefix          = var.eks_name_prefix
  eks_resource_prefix      = var.eks_resource_prefix
  node_groups_ready        = var.node_groups_ready
  pod_identity_addon_ready = var.pod_identity_addon_ready
}

module "external_dns" {
  source = "../../modules/helm-external-dns"

  cluster_name = var.cluster_name
  # External DNS must manage records under the APEX, because platform hosts are
  # single-label there (stg-argocd.zordnet.com) so the one wildcard cert matches.
  # Filtering only on env_domain (staging.zordnet.com) would never match them and
  # no Route53 record would be created.
  domain                   = var.apex_domain
  eks_name_prefix          = var.eks_name_prefix
  eks_resource_prefix      = var.eks_resource_prefix
  node_groups_ready        = var.node_groups_ready
  pod_identity_addon_ready = var.pod_identity_addon_ready
}
module "external_secrets" {
  source = "../../modules/helm-external-secrets"

  cluster_name        = var.cluster_name
  aws_region          = var.aws_region
  eks_name_prefix     = var.eks_name_prefix
  eks_resource_prefix = var.eks_resource_prefix
  namespace           = var.external_secrets_namespace
  service_account     = var.external_secrets_service_account
  secret_arns         = var.secret_arns
  node_groups_ready   = var.node_groups_ready
}

module "argo_rollouts" {
  source = "../../modules/helm-argo-rollouts"

  node_groups_ready = var.node_groups_ready
}

module "argocd" {
  source = "../../modules/helm-argocd"

  environment             = var.environment
  domain                  = var.apex_domain
  host_prefix             = var.platform_host_prefix
  acm_certificate_arn     = var.acm_certificate_arn
  shared_alb_group        = var.argocd_alb_group
  github_pat              = var.github_pat
  app_repo_url            = var.app_repo_url
  application_mode        = var.application_mode
  app_target_revision     = var.app_target_revision
  values_environment      = var.values_environment
  applications_auto_sync  = var.applications_auto_sync
  observability_auto_sync = var.observability_auto_sync
  application_name_suffix = var.application_name_suffix
  node_groups_ready       = var.node_groups_ready
}
