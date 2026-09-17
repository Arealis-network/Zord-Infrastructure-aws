##########################################################################
# SHARED NAMING + TAGGING CONTRACT
#
# Every component derives names from these maps, so all six components in an
# environment agree on cluster name, prefixes and tags without duplicating logic.
#
# Source of truth - copied into each component directory as locals.tf.
# Do not edit the copies.
##########################################################################

locals {
  # 3-way map (never a binary ternary): a binary "production ? prod : stg" would
  # silently give dev the SAME names and CIDR as staging.
  env_short_map = {
    production = "prod"
    staging    = "stg"
    dev        = "dev"
  }
  env_short = local.env_short_map[var.environment]

  # Full env word used in DNS names (staging/dev, not the short "stg").
  env_short_full = var.environment == "staging" ? "staging" : "dev"

  # ── Names ──
  cluster_name        = "arealis-zord-${local.env_short}-eks"
  eks_name_prefix     = "Arealis zord ${local.env_short} eks"
  eks_resource_prefix = "arealis-zord-${local.env_short}-eks"
  vpc_name_prefix     = "Arealis zord ${local.env_short} vpc"
  vpc_resource_prefix = "arealis-zord-${local.env_short}-vpc"
  node_group_name     = "arealis-zord-${local.env_short}-eks-node-group"

  # ── DNS ──
  # Explicit tfvars value wins; otherwise derive (prod = apex, non-prod = subdomain).
  env_domain = var.env_domain != "" ? var.env_domain : (
    var.environment == "production" ? var.ses_domain : "${local.env_short_full}.${var.ses_domain}"
  )

  # ── Network ──
  # Non-overlapping per environment so all three coexist in the shared account.
  env_cidr_map = {
    production = { vpc = "10.0.0.0/16", pub1 = "10.0.1.0/24", pub2 = "10.0.2.0/24", priv1 = "10.0.3.0/24", priv2 = "10.0.4.0/24" }
    staging    = { vpc = "10.1.0.0/16", pub1 = "10.1.1.0/24", pub2 = "10.1.2.0/24", priv1 = "10.1.3.0/24", priv2 = "10.1.4.0/24" }
    dev        = { vpc = "10.2.0.0/16", pub1 = "10.2.1.0/24", pub2 = "10.2.2.0/24", priv1 = "10.2.3.0/24", priv2 = "10.2.4.0/24" }
  }
  vpc_cidr      = var.vpc_cidr != "" ? var.vpc_cidr : local.env_cidr_map[var.environment].vpc
  public1_cidr  = var.public1_cidr != "" ? var.public1_cidr : local.env_cidr_map[var.environment].pub1
  public2_cidr  = var.public2_cidr != "" ? var.public2_cidr : local.env_cidr_map[var.environment].pub2
  private1_cidr = var.private1_cidr != "" ? var.private1_cidr : local.env_cidr_map[var.environment].priv1
  private2_cidr = var.private2_cidr != "" ? var.private2_cidr : local.env_cidr_map[var.environment].priv2

  # ── S3 bucket names ──
  # Globally unique. Production keeps the original unprefixed names (a bucket
  # cannot be renamed without destroying it, which would delete the evidence vault).
  bucket_prefix = var.environment == "production" ? "" : "${local.env_short}-"
  bucket_names = {
    edge       = var.edge_bucket_name != "" ? var.edge_bucket_name : "${local.bucket_prefix}zord-edge-ingress"
    canonical  = var.canonical_bucket_name != "" ? var.canonical_bucket_name : "${local.bucket_prefix}zord-intent-engine-canonical"
    nir        = var.nir_bucket_name != "" ? var.nir_bucket_name : "${local.bucket_prefix}zord-intent-engine-nir"
    governance = var.governance_bucket_name != "" ? var.governance_bucket_name : "${local.bucket_prefix}zord-intent-engine-governance"
    outcome    = var.outcome_bucket_name != "" ? var.outcome_bucket_name : "${local.bucket_prefix}zord-outcome-engine-settlement-ingress"
    evidence   = var.evidence_bucket_name != "" ? var.evidence_bucket_name : "${local.bucket_prefix}zord-evidence-vault"
  }

  # ── Ingress ──
  # Per-env ALB group: a shared value makes non-prod discover production's ALB.
  kong_alb_group_map = {
    production = "zord-shared-alb"
    staging    = "zord-staging-alb"
    dev        = "zord-dev-alb"
  }
  kong_alb_stack_tag = var.kong_alb_stack_tag != "" ? var.kong_alb_stack_tag : local.kong_alb_group_map[var.environment]

  argocd_alb_group_map = {
    production = "zord-observability"
    staging    = "zord-staging-alb"
    dev        = "zord-dev-alb"
  }
  argocd_alb_group = var.argocd_alb_group != "" ? var.argocd_alb_group : local.argocd_alb_group_map[var.environment]

  # ── Tags applied to every resource via provider default_tags ──
  common_tags = {
    Environment = var.environment
    Project     = "arealis-zord-eks"
    Owner       = "yaswanth"
    ManagedBy   = "Terraform"
    Cluster     = local.cluster_name
  }

  # ── Remote state keys (how components read each other) ──
  state_keys = {
    foundation = "eks/${var.environment}/01-foundation.tfstate"
    data       = "eks/${var.environment}/02-data.tfstate"
    compute    = "eks/${var.environment}/03-compute.tfstate"
    security   = "eks/${var.environment}/04-security.tfstate"
    platform   = "eks/${var.environment}/05-platform.tfstate"
  }
}
