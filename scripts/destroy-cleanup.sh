#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# destroy-cleanup.sh — best-effort cleanup of resources Terraform does NOT own,
# so a `terraform destroy` of an environment completes and leaves no footprint.
#
# Two phases (K8s controllers create these OUTSIDE Terraform state):
#   sweep  — delete orphaned ALBs/NLBs + public-IP ENIs in the env's VPC.
#            Run AFTER 05-platform (the LB controller) is destroyed, else the
#            controller just recreates the ALB from the Ingress. Orphaned ALBs
#            keep public IPs in the subnets and block the VPC destroy with
#            "mapped public address(es)" / "subnet has dependencies".
#   dns    — delete the env's orphaned Route53 records (stg-* / dev-*) left by
#            External DNS (grafana/jaeger/kibana ingresses). Run AFTER all
#            components are destroyed. PRODUCTION IS SKIPPED (its records are
#            un-prefixed apex names like api/www — too risky to auto-delete).
#
# NEVER aborts: every step is best-effort. A failure here must not fail destroy.
#
# Usage:
#   destroy-cleanup.sh sweep <environment> <aws_region>
#   destroy-cleanup.sh dns   <environment> <aws_region>
# ─────────────────────────────────────────────────────────────────────────────
set +e

PHASE="${1:-}"
ENVIRONMENT="${2:-}"
REGION="${3:-ap-south-1}"
CONFIG="live/environments/${ENVIRONMENT}/config.json"

if [[ -z "$PHASE" || -z "$ENVIRONMENT" ]]; then
  echo "usage: $0 <sweep|dns> <environment> [aws_region]" >&2
  exit 0 # non-fatal
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "cleanup: config not found ($CONFIG) — skipping" >&2
  exit 0
fi

cluster=$(jq -r .cluster_name "$CONFIG")

# ── phase: sweep orphaned ALBs/NLBs + ENIs so the VPC can be destroyed ──
sweep() {
  local vpc
  # Prefer the EKS API (authoritative). Fallback to the VPC's Name tag.
  vpc=$(aws eks describe-cluster --name "$cluster" --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
  if [[ -z "$vpc" || "$vpc" == "None" ]]; then
    vpc=$(aws ec2 describe-vpcs --region "$REGION" \
      --filters "Name=tag:Name,Values=$(jq -r .vpc_name_prefix "$CONFIG")" \
      --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
  fi
  if [[ -z "$vpc" || "$vpc" == "None" ]]; then
    echo "sweep: no VPC found for $ENVIRONMENT — nothing to sweep"; return 0
  fi

  echo "::group::AWS sweep for VPC $vpc"
  # 1. delete every ELBv2 (ALB/NLB) in the VPC
  for arn in $(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId=='$vpc'].LoadBalancerArn" --output text 2>/dev/null); do
    echo "deleting load balancer $arn"
    aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" 2>/dev/null
  done
  # 2. delete classic ELBs (if any)
  for name in $(aws elb describe-load-balancers --region "$REGION" \
    --query "LoadBalancerDescriptions[?VPCId=='$vpc'].LoadBalancerName" --output text 2>/dev/null); do
    aws elb delete-load-balancer --region "$REGION" --load-balancer-name "$name" 2>/dev/null
  done
  # 3. wait (up to ~3m) for LB ENIs holding public IPs to drain
  for _ in $(seq 1 18); do
    local left
    left=$(aws ec2 describe-network-interfaces --region "$REGION" \
      --filters "Name=vpc-id,Values=$vpc" \
      --query "length(NetworkInterfaces[?Association.PublicIp!=null])" --output text 2>/dev/null || echo 0)
    [[ "$left" == "0" ]] && break
    echo "waiting for $left public-IP ENIs to release..."; sleep 10
  done
  # 4. force-detach + delete any ENI still holding a public IP
  for eni in $(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc" \
    --query "NetworkInterfaces[?Association.PublicIp!=null].NetworkInterfaceId" --output text 2>/dev/null); do
    local att
    att=$(aws ec2 describe-network-interfaces --region "$REGION" --network-interface-ids "$eni" \
      --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null)
    [[ "$att" != "None" && -n "$att" ]] && aws ec2 detach-network-interface --region "$REGION" --attachment-id "$att" --force 2>/dev/null
    sleep 5
    aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni" 2>/dev/null
  done
  # 5. delete remaining available ENIs so subnets can be removed
  for eni in $(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters "Name=vpc-id,Values=$vpc" "Name=status,Values=available" \
    --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null); do
    aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni" 2>/dev/null
  done
  echo "::endgroup::"
}

# ── phase: delete the env's orphaned Route53 records (stg-* / dev-*) ──
dns() {
  local pfx=""
  [[ "$ENVIRONMENT" == "staging" ]] && pfx="stg-"
  [[ "$ENVIRONMENT" == "dev" ]] && pfx="dev-"
  if [[ -z "$pfx" ]]; then
    echo "dns: skipping ($ENVIRONMENT has no safe prefix; production is never auto-cleaned)"; return 0
  fi
  local apex zid n
  apex=$(jq -r .dns.ses_domain "$CONFIG")
  zid=$(aws route53 list-hosted-zones-by-name --dns-name "$apex" \
    --query 'HostedZones[0].Id' --output text 2>/dev/null | sed 's|/hostedzone/||')
  if [[ -z "$zid" || "$zid" == "None" ]]; then
    echo "dns: no hosted zone for $apex"; return 0
  fi
  echo "::group::DNS cleanup ($pfx*) in zone $apex"
  # jq emits the exact ResourceRecordSet objects Route53 returned (TTL/alias/values
  # preserved), excluding NS/SOA, as a DELETE change-batch.
  aws route53 list-resource-record-sets --hosted-zone-id "$zid" --output json 2>/dev/null \
    | jq --arg p "$pfx" '{Changes: [ .ResourceRecordSets[]
        | select(.Name | startswith($p))
        | select(.Type != "NS" and .Type != "SOA")
        | {Action: "DELETE", ResourceRecordSet: .} ]}' > /tmp/dns_del.json
  n=$(jq '.Changes | length' /tmp/dns_del.json 2>/dev/null || echo 0)
  if [[ "$n" -gt 0 ]]; then
    aws route53 change-resource-record-sets --hosted-zone-id "$zid" \
      --change-batch file:///tmp/dns_del.json 2>/dev/null \
      && echo "deleted $n $pfx records" || echo "DNS delete failed (non-fatal)"
  else
    echo "no $pfx records to delete"
  fi
  echo "::endgroup::"
}

case "$PHASE" in
  sweep) sweep ;;
  dns)   dns ;;
  *)     echo "unknown phase '$PHASE' (use sweep|dns)" >&2 ;;
esac

exit 0
