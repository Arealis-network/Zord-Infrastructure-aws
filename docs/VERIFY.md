# Post-Apply Verification (run on the bastion)

After the pipeline applies an environment, SSH to that env's bastion and run these
commands to confirm every tool is installed and healthy. Copy-paste blocks as-is.

```bash
# ── 0. Connect + point kubectl at THIS env's cluster ──
# (bastion IP is in the pipeline "apply" summary; sudo -i then run these)
ENV=staging                              # staging | dev | production
CLUSTER=$(case $ENV in production) echo arealis-zord-prod-eks;; staging) echo arealis-zord-stg-eks;; dev) echo arealis-zord-dev-eks;; esac)
REGION=ap-south-1
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
kubectl config current-context
```

---

## 1. Cluster + nodes

```bash
kubectl get nodes -o wide
kubectl get nodes -L karpenter.sh/nodepool -L node.kubernetes.io/instance-type -L karpenter.sh/capacity-type
kubectl top nodes                        # needs metrics-server (see §4)
```

---

## 2. Karpenter (node autoscaling — replaced Cluster Autoscaler)

```bash
# controller pods must be Running
kubectl -n kube-system get pods -l app.kubernetes.io/name=karpenter

# the scaling policy objects must exist
kubectl get nodepool
kubectl get ec2nodeclass

# live scaling decisions (launch / consolidation)
kubectl -n kube-system logs -l app.kubernetes.io/name=karpenter --tail=40 | grep -iE "launched|consolidat|disrupt|registered"

# NOTE: the OLD cluster-autoscaler must NOT exist anymore — this should be EMPTY:
kubectl -n kube-system get pods | grep -i cluster-autoscaler || echo "OK: no cluster-autoscaler (expected)"
```

Quick scale test (optional): create dummy pods, watch Karpenter add a node, delete, watch it remove.
```bash
kubectl create deploy scaletest --image=public.ecr.aws/nginx/nginx:latest --replicas=8
kubectl scale deploy scaletest --replicas=30      # forces new node(s)
kubectl get nodes -w                              # a new node appears in ~30-60s
kubectl delete deploy scaletest                   # node drains + terminates after consolidateAfter
```

---

## 3. AWS Load Balancer Controller + External DNS

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl -n kube-system get pods -l app.kubernetes.io/name=external-dns

# ingresses -> ALBs -> DNS
kubectl get ingress -A
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=25
kubectl -n kube-system logs -l app.kubernetes.io/name=external-dns --tail=25
```

---

## 4. Metrics Server (needed for HPA + `kubectl top`)

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=metrics-server
kubectl top pods -A | head
kubectl get hpa -A
```

---

## 5. EBS CSI driver + default StorageClass

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver
kubectl get storageclass                 # gp3 should be (default)
kubectl get pvc -A
```

---

## 6. External Secrets Operator (ESO) + secret sync

```bash
kubectl -n external-secrets get pods
kubectl get clustersecretstore                       # must be Valid=True
kubectl get externalsecret -A                        # all READY=True
# if one is not ready, inspect it:
# kubectl -n <ns> describe externalsecret <name>
```

---

## 7. ArgoCD + the 5 Applications

```bash
kubectl -n argocd get pods
kubectl -n argocd get applications -o wide
# expect: zord-platform-<env>, kong-gateway-<env>, zord-logging-<env>,
#         zord-monitoring-<env>, zord-tracing-<env>  (Synced / Healthy)
```

---

## 8. Observability (Prometheus / Grafana / ELK / Jaeger)

```bash
kubectl -n monitoring get pods           # prometheus, grafana, node-exporter, kube-state-metrics
kubectl -n logging get pods              # elasticsearch, kibana, fluent-bit
kubectl -n tracing get pods              # jaeger + otel collector
kubectl get crd | grep monitoring.coreos.com | head   # kube-prometheus-stack CRDs
```

---

## 9. App workloads (zord + kong)

```bash
kubectl -n zord get pods
kubectl -n api-gateway get pods
# Kafka (KRaft) — all brokers should be Running/Ready:
kubectl -n zord get pods -l app.kubernetes.io/name=zord-kafka
```

---

## 10. Cost guardrails — confirm the CloudWatch fixes held

```bash
# EKS control-plane logging should be DISABLED (no vended-log cost):
aws eks describe-cluster --name "$CLUSTER" --region "$REGION" \
  --query 'cluster.logging.clusterLogging' --output json

# No env log groups should be growing (empty or absent = $0):
aws logs describe-log-groups --region "$REGION" \
  --query 'logGroups[].{Name:logGroupName,GB:storedBytes}' --output table

# No orphaned public-IP ENIs / unattached EBS (leftover cost):
VPC=$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$VPC" \
  --query "NetworkInterfaces[?Association.PublicIp!=null].NetworkInterfaceId" --output text
aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available \
  --query "Volumes[].{Id:VolumeId,GB:Size}" --output table
```

---

## 11. One-shot "is everything up?" summary

```bash
echo "== nodes =="        ; kubectl get nodes --no-headers | wc -l
echo "== karpenter =="    ; kubectl -n kube-system get pods -l app.kubernetes.io/name=karpenter --no-headers | grep -c Running
echo "== lb-controller ==" ; kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers | grep -c Running
echo "== external-dns =="  ; kubectl -n kube-system get pods -l app.kubernetes.io/name=external-dns --no-headers | grep -c Running
echo "== metrics-server ==" ; kubectl -n kube-system get pods -l app.kubernetes.io/name=metrics-server --no-headers | grep -c Running
echo "== eso store =="     ; kubectl get clustersecretstore --no-headers 2>/dev/null
echo "== argocd apps =="   ; kubectl -n argocd get applications --no-headers 2>/dev/null | awk '{print $1,$2,$3}'
```

> If any pod is not Running, describe it: `kubectl -n <namespace> describe pod <name>` and check `kubectl -n <namespace> logs <name>`.
