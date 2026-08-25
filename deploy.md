# Zord Infrastructure — Deployment Guide

## Prerequisites

Before deploying, ensure these exist in your new AWS account:

| Requirement | Where to create |
|---|---|
| OIDC Identity Provider | IAM → Identity providers → Add (`token.actions.githubusercontent.com`) |
| IAM Role for GitHub Actions | IAM → Roles → `zord-infrastructure-aws-role` |
| S3 Terraform state bucket | S3 → `zord-infrastructure-aws-tf-state` (versioned, encrypted, private) |
| ACM wildcard certificate | ACM → `*.zordnet.com` (must be ISSUED before deploy) |
| GitHub secrets configured | See table below |

## GitHub Repository Secrets

```
GitHub repo → Settings → Secrets and variables → Actions
```

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::673698305621:role/zord-infrastructure-aws-role` |
| `TF_STATE_BUCKET` | `zord-infrastructure-aws-tf-state` |

## Deploy (One Click)

```
GitHub Actions → Zord Infrastructure → Run workflow
    Environment: production (or staging)
    Action: apply
```

One `terraform apply` creates everything:

```
VPC → EKS Cluster → Node Groups → Addons → EBS CSI → KMS Key →
S3 Buckets (6) → Per-Service S3 Roles → Secrets Manager (37 keys) →
EC2 Admin (Jenkins + SonarQube) → SES Email → Cluster Autoscaler →
External Secrets Operator + ClusterSecretStore
```

## After Apply — What to Do

### Step 1: Update secrets in AWS Console

```
AWS Console → Secrets Manager → production/zord/app-secrets → Retrieve secret value → Edit
```

Replace all `CHANGE_ME` values with real passwords/keys. The following are auto-populated by Terraform (no manual edit needed):

| Key | Auto-populated |
|---|---|
| `S3_KMS_KEY_ID` | ✅ KMS key ARN from Terraform |
| `ACM_CERTIFICATE_ARN` | ✅ Fetched from ACM |
| All `*_S3_BUCKET` keys | ✅ Real bucket names |

### Step 2: Update signing keys

```
AWS Console → Secrets Manager → production/zord/edge-signing-key → Edit
```

Replace `CHANGE_ME` with your real ed25519 private key (use `\n` for newlines).

Same for `production/zord/evidence-signing-key`.

### Step 3: Connect to EKS cluster

```bash
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-prod-eks
kubectl get nodes
```

### Step 4: Deploy application (from app repo)

```bash
kubectl apply -k kubernetes/eks
kubectl wait --for=condition=Ready pod/zord-postgres-0 -n zord --timeout=300s
kubectl wait --for=condition=Ready pod/zord-kafka-0 -n zord --timeout=300s
kubectl apply -k kubernetes/api-gateway
```

### Step 5: Point DNS to ALB

```bash
kubectl get ingress -n api-gateway
```

Copy the ALB DNS name → create CNAME records:
- `zordnet.com` → ALB
- `api.zordnet.com` → ALB
- `www.zordnet.com` → ALB

## Access

| Service | URL |
|---|---|
| Jenkins | `http://<EC2_ELASTIC_IP>:7777` |
| SonarQube | `http://<EC2_ELASTIC_IP>:7771` |
| EKS | `aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-prod-eks` |

Get the Elastic IP:

```
Terraform output → ec2_public_ip (shown in apply summary)
```

## Destroy (One Click)

```
GitHub Actions → Zord Infrastructure → Run workflow
    Environment: production
    Action: destroy
    confirm_destroy: yes
```

Automated cleanup:
1. Removes webhooks + finalizers
2. Uninstalls all Helm releases
3. Deletes LoadBalancer services + Ingresses + PVCs
4. Waits 90s for AWS to release resources
5. `terraform destroy`
6. Retries with ENI/SG cleanup if first attempt fails
7. Verifies every AWS resource is deleted (13 checks)

## What Gets Created (per environment)

| Category | Resources |
|---|---|
| **Network** | VPC, 2 public + 2 private subnets, IGW, NAT, routes, security group |
| **EKS** | Cluster (v1.32), OIDC provider, access entries |
| **Nodes** | Stateful (t3.xlarge on-demand), Stateless (spot: t3.large/xlarge/m5.large) |
| **Addons** | vpc-cni (NetworkPolicy), coredns, kube-proxy, pod-identity, EBS CSI |
| **Storage** | KMS key + 6 S3 buckets (SSE-KMS, versioned, private) |
| **Security** | 4 per-service S3 IAM roles (PLAT-07), ESO role, autoscaler role, SES role |
| **Secrets** | 3 AWS Secrets Manager secrets (37 keys pre-filled) |
| **Compute** | EC2 admin (Elastic IP, Jenkins, SonarQube, auto-stop 10PM/start 9AM) |
| **Email** | SES domain (zordnet.com), DKIM, support@ and no-reply@ |
| **Helm** | Cluster Autoscaler, External Secrets Operator + ClusterSecretStore |

## Module Structure

```
EKS-terraform/modules/
├── aws-vpc/                    ← VPC + subnets + NAT + routes + SG
├── aws-eks-cluster/            ← EKS + OIDC + cluster IAM role
├── aws-eks-node-groups/        ← Node groups + worker IAM role
├── aws-eks-addons/             ← Core addons (vpc-cni, coredns, kube-proxy, pod-identity)
├── aws-ebs-csi/                ← EBS CSI IAM + pod identity + addon
├── aws-kms/                    ← KMS key for S3 encryption
├── aws-s3-buckets/             ← 6 private buckets with SSE-KMS
├── aws-s3-access/              ← Per-service IAM roles (PLAT-07 least privilege)
├── aws-secrets-manager/        ← 3 secrets with all key-values pre-filled
├── aws-ec2-admin/              ← EC2 + EIP + scheduler + tool.sh
├── aws-ses-email/              ← SES + IAM + pod identity
├── helm-cluster-autoscaler/    ← IAM + pod identity + Helm (self-contained)
└── helm-external-secrets/      ← IAM + pod identity + Helm + ClusterSecretStore
```

## Security Features

| Feature | Status |
|---|---|
| GitHub OIDC (no static AWS keys) | ✅ |
| EKS Pod Identity (not IRSA) | ✅ |
| Per-service S3 roles (PLAT-07) | ✅ |
| KMS encryption on all S3 buckets | ✅ |
| NetworkPolicy enforcement (VPC CNI) | ✅ |
| IMDSv2 enforced on all nodes | ✅ |
| EKS private + public endpoint | ✅ |
| Secrets never in Terraform state | ✅ |
| S3 versioning (immutable history) | ✅ |
| EC2 restricted security group (22, 7777, 7771 only) | ✅ |
| Secrets 7-day recovery window | ✅ |
| KMS key auto-rotation | ✅ |
| S3 public access fully blocked | ✅ |
