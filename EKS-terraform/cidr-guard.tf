# ═══════════════════════════════════════════════════════════════════
# CIDR CONFLICT GUARD (shared-account safety)
#
# This project runs in an AWS account shared with other teams, so we cannot
# create an account-level VPC IPAM (that would be an org-wide resource - the same
# reason Compute Optimizer / Resource Explorer are deliberately not managed here).
#
# Instead we do the next best thing, which is what the IPAM overlap check does
# for you: BEFORE creating anything, discover every VPC CIDR already in use in
# this region and fail the plan with an explicit message if the CIDR this
# environment wants would overlap. Turns a silent, painful-to-unwind networking
# mistake into an immediate, readable error.
#
# Our own VPC is excluded, so re-applying an existing environment never trips it.
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
  want_cidr   = local.vpc_cidr
  want_prefix = tonumber(split("/", local.want_cidr)[1])
  want_octets = split(".", split("/", local.want_cidr)[0])
  want_start = (
    tonumber(local.want_octets[0]) * 16777216 +
    tonumber(local.want_octets[1]) * 65536 +
    tonumber(local.want_octets[2]) * 256 +
    tonumber(local.want_octets[3])
  )
  want_end = local.want_start + pow(2, 32 - local.want_prefix) - 1

  # ── Existing VPCs that are NOT this environment's own VPC ──
  # Our VPC carries Cluster=<cluster_name> via provider default_tags, so excluding
  # it keeps re-applies idempotent.
  other_vpcs = {
    for id, v in data.aws_vpc.discovered : id => v
    if try(v.tags["Cluster"], "") != local.cluster_name
  }

  # Numeric range of every other VPC's primary CIDR.
  other_ranges = {
    for id, v in local.other_vpcs : id => {
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

  # Two ranges overlap when each starts at or before the other ends.
  cidr_conflicts = [
    for id, r in local.other_ranges :
    "${r.cidr} (VPC ${id}, Name=${r.name})"
    if local.want_start <= (r.start + r.size - 1) && r.start <= local.want_end
  ]
}

# Fails the PLAN (before any resource is touched) when the chosen CIDR overlaps
# an existing VPC in this account/region.
resource "terraform_data" "cidr_guard" {
  input = local.want_cidr

  lifecycle {
    precondition {
      condition = length(local.cidr_conflicts) == 0
      error_message = join("\n", [
        "VPC CIDR CONFLICT - refusing to create overlapping network.",
        "",
        "Environment '${var.environment}' wants: ${local.want_cidr}",
        "It overlaps these existing VPC(s) in ${var.aws_region}:",
        join("\n", [for c in local.cidr_conflicts : "  - ${c}"]),
        "",
        "Fix: pick a free /16 and set it in local.env_cidr_map in main.tf",
        "(current map: production=10.0.0.0/16, staging=10.1.0.0/16, dev=10.2.0.0/16).",
        "List what is already allocated with:",
        "  aws ec2 describe-vpcs --region ${var.aws_region} --query 'Vpcs[].{ID:VpcId,CIDR:CidrBlock}' --output table",
      ])
    }
  }
}
