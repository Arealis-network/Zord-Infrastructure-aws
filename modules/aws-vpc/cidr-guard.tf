# ═══════════════════════════════════════════════════════════════════
# CIDR CONFLICT GUARD (shared-account safety)
#
# This project runs in an AWS account shared with other teams, so we cannot
# create an account-level VPC IPAM (that would be an org-wide resource - the same
# reason Compute Optimizer / Resource Explorer are deliberately not managed here).
#
# Instead we do what IPAM's overlap check does for you: BEFORE creating anything,
# discover every VPC CIDR already in use in this region and fail the PLAN with an
# explicit message if this environment's CIDR would overlap. That turns a silent,
# painful-to-unwind networking mistake into an immediate, readable error.
#
# Our own VPC is excluded (matched on the Cluster tag), so re-applying an existing
# environment never trips the guard.
# ═══════════════════════════════════════════════════════════════════

# All VPCs in the target region (every team's, including ours).
data "aws_vpcs" "all" {}

# CIDR + tags for each discovered VPC.
data "aws_vpc" "discovered" {
  for_each = toset(data.aws_vpcs.all.ids)
  id       = each.value
}

locals {
  # ── The CIDR this environment intends to create ──
  guard_prefix = tonumber(split("/", var.vpc_cidr)[1])
  guard_octets = split(".", split("/", var.vpc_cidr)[0])
  guard_start = (
    tonumber(local.guard_octets[0]) * 16777216 +
    tonumber(local.guard_octets[1]) * 65536 +
    tonumber(local.guard_octets[2]) * 256 +
    tonumber(local.guard_octets[3])
  )
  guard_end = local.guard_start + pow(2, 32 - local.guard_prefix) - 1

  # ── Existing VPCs that are NOT this environment's own VPC ──
  # Our VPC carries Cluster=<cluster_name> via the provider default_tags, so
  # excluding it keeps re-applies idempotent.
  guard_other_vpcs = {
    for id, v in data.aws_vpc.discovered : id => v
    if try(v.tags["Cluster"], "") != var.cluster_name
  }

  # Numeric range of every other VPC's primary CIDR.
  guard_other_ranges = {
    for id, v in local.guard_other_vpcs : id => {
      cidr = v.cidr_block
      name = try(v.tags["Name"], "(untagged)")
      start = (
        tonumber(split(".", split("/", v.cidr_block)[0])[0]) * 16777216 +
        tonumber(split(".", split("/", v.cidr_block)[0])[1]) * 65536 +
        tonumber(split(".", split("/", v.cidr_block)[0])[2]) * 256 +
        tonumber(split(".", split("/", v.cidr_block)[0])[3])
      )
      size = pow(2, 32 - tonumber(split("/", v.cidr_block)[1]))
    }
  }

  # Two ranges overlap when each starts at or before the other ends. This catches
  # exact duplicates, a /16 nested inside someone's /8, and partial overlaps -
  # while correctly ALLOWING adjacent-but-separate ranges.
  guard_conflicts = [
    for id, r in local.guard_other_ranges :
    "${r.cidr} (VPC ${id}, Name=${r.name})"
    if local.guard_start <= (r.start + r.size - 1) && r.start <= local.guard_end
  ]
}

# Fails the PLAN (before any resource is touched) when the chosen CIDR overlaps
# an existing VPC in this account/region.
resource "terraform_data" "cidr_guard" {
  input = var.vpc_cidr

  lifecycle {
    precondition {
      condition = length(local.guard_conflicts) == 0
      error_message = join("\n", [
        "VPC CIDR CONFLICT - refusing to create an overlapping network.",
        "",
        "Environment '${var.environment}' wants: ${var.vpc_cidr}",
        "It overlaps these existing VPC(s) in ${var.aws_region}:",
        join("\n", [for c in local.guard_conflicts : "  - ${c}"]),
        "",
        "Fix: pick a free /16 and set network.vpc_cidr in live/environments/<env>/config.json",
        "(current map: production=10.0.0.0/16, staging=10.1.0.0/16, dev=10.2.0.0/16).",
        "List what is already allocated with:",
        "  aws ec2 describe-vpcs --region ${var.aws_region} --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock}' --output table",
      ])
    }
  }
}
