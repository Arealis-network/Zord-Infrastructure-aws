# ═══════════════════════════════════════════════════════════════════
# AWS Load Balancer Controller — turns Ingress/Service objects into
# real AWS ALBs/NLBs. This is what creates the single shared ALB
# (group.name: zord-shared-alb) that fronts Kong + ArgoCD.
# Self-contained: IAM Policy + Role + Pod Identity + Helm.
# ═══════════════════════════════════════════════════════════════════

resource "aws_iam_policy" "lb_controller" {
  name        = "${var.eks_resource_prefix}-lb-controller-policy"
  description = "AWS Load Balancer Controller permissions (create/manage ALB/NLB)."
  policy      = file("${path.module}/iam-policy.json")

  tags = {
    Name = "${var.eks_name_prefix} lb controller policy"
  }
}

resource "aws_iam_role" "lb_controller" {
  name = "${var.eks_resource_prefix}-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Name = "${var.eks_name_prefix} lb controller role"
  }
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn

  depends_on = [
    aws_iam_role_policy_attachment.lb_controller,
    var.pod_identity_addon_ready
  ]
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # Disable the Service mutating webhook. We expose everything via Ingress (ALB),
  # NOT Service type=LoadBalancer, so we don't need it. Leaving it on makes the
  # webhook intercept EVERY Service creation cluster-wide — and while the controller
  # pods are still starting, that blocks other charts (e.g. External Secrets) with
  # "no endpoints available for aws-load-balancer-webhook-service". Off = no race.
  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }

  depends_on = [
    aws_eks_pod_identity_association.lb_controller,
    var.node_groups_ready
  ]
}

# Destroy-time safety net. ALBs/NLBs are created by THIS controller from the app's
# Ingress/Service objects — they are NOT in Terraform state. If the controller is
# torn down before those objects are removed, the orphaned ALBs keep ENIs + public
# IPs in the subnets, and the VPC destroy fails with:
#   "has some mapped public address(es)" / "subnet has dependencies".
# This resource depends_on the controller release, so on `terraform destroy` it is
# destroyed FIRST — it deletes the Ingress/LoadBalancer objects (controller then
# deprovisions the ALBs) and directly sweeps any ELBv2 left in the VPC. No-op on apply.
resource "null_resource" "alb_cleanup" {
  triggers = {
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
    vpc_id       = var.vpc_id
  }

  depends_on = [helm_release.lb_controller]

  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set +e
      REGION="${self.triggers.aws_region}"; VPC="${self.triggers.vpc_id}"
      aws eks update-kubeconfig --name "${self.triggers.cluster_name}" --region "$REGION" >/dev/null 2>&1
      # Best-effort: delete the k8s objects that spawn ALBs/NLBs (if the cluster is
      # still reachable) so the controller deprovisions them cleanly.
      kubectl delete ingress --all-namespaces --all --wait=false 2>/dev/null
      kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --wait=false 2>/dev/null

      # Primary fix: delete ALL ELBv2 (ALB/NLB) in this VPC directly. This works even
      # if the controller is already gone (orphaned LB) — the case that broke destroy.
      for arn in $(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?VpcId=='$VPC'].LoadBalancerArn" --output text 2>/dev/null); do
        aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" 2>/dev/null
      done

      # Wait (up to ~3m) for the LB ENIs holding public IPs to drain — those are the
      # "mapped public address(es)" that block IGW detach.
      for i in $(seq 1 18); do
        left=$(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC" --query "length(NetworkInterfaces[?Association.PublicIp!=null])" --output text 2>/dev/null)
        [ "$left" = "0" ] && break
        sleep 10
      done

      # Force-detach + delete any ENI that still holds a public IP.
      for eni in $(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC" --query "NetworkInterfaces[?Association.PublicIp!=null].NetworkInterfaceId" --output text 2>/dev/null); do
        att=$(aws ec2 describe-network-interfaces --region "$REGION" --network-interface-ids "$eni" --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null)
        [ "$att" != "None" ] && [ -n "$att" ] && aws ec2 detach-network-interface --region "$REGION" --attachment-id "$att" --force 2>/dev/null
        sleep 5
        aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni" 2>/dev/null
      done

      # Delete any remaining available ENIs so subnets can be removed.
      for eni in $(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC" "Name=status,Values=available" --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null); do
        aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$eni" 2>/dev/null
      done
      exit 0
    EOT
  }
}
