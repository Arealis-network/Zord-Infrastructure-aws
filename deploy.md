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
| `GITHUB_PAT_ARGOCD` | GitHub Personal Access Token (for ArgoCD repo access) |

## GitHub Repository Variables

```
GitHub repo → Settings → Secrets and variables → Actions → Variables tab
```

These are **variables** (not secrets — not sensitive). All have safe defaults, so you only set them if you want to override:

| Variable | Default | Purpose |
|---|---|---|
| `ZORD_DOMAIN` | `zordnet.com` | Root domain. Drives SES, ACM lookup, and the CloudFront entrypoint (`api.<domain>`). |
| `ENABLE_CLOUDFRONT_EDGE` | `true` | Master switch for the CloudFront + WAF edge layer. Self-healing: if Kong's ALB doesn't exist yet, the edge skips itself this apply and comes up automatically on a later apply. Set `false` to hard-disable. |
| `KONG_ALB_STACK_TAG` | `zord-shared-alb` | The `ingress.k8s.aws/stack` tag the AWS LB Controller puts on the shared ALB fronting Kong. Terraform uses it to auto-discover the ALB (no manual hostname). |

Change the domain later = edit `ZORD_DOMAIN` only. No code change.

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
| `EVIDENCE_KMS_KEY_ARN` | ✅ Evidence archive KMS key |
| All `*_S3_BUCKET` keys | ✅ Real bucket names |

Keys that need manual values:

| Key | What to put | How to generate |
|---|---|---|
| `VAULT_KEY_ID` | Identifier for your vault key (e.g., `vault-key-v1`) | Choose any unique string |
| `ZORD_VAULT_KEY` | 32-byte base64 encryption key | `openssl rand -base64 32` |
| `MASTER_KEY` | Token enclave master key (base64) | `openssl rand -base64 32` |
| `TOKEN_SECRET` | Token signing secret (base64) | `openssl rand -base64 32` |
| `JWT_SIGNING_SECRET` | JWT signing secret (base64) | `openssl rand -base64 32` |
| `ENCLAVE_INTERNAL_TOKEN` | Internal auth token (base64) | `openssl rand -base64 32` |
| `TOKENIZED_DATA_HASH_MASTER_SECRET` | Hash master secret (base64) | `openssl rand -base64 32` |
| `INTERNAL_ADMIN_KEY` | Admin API key | Choose any strong string |
| All `*_DB_PASSWORD` | Database passwords | `openssl rand -base64 16` per password |
| `GEMINI_API_KEYS` | Google Gemini API key | Get from Google AI Studio |
| All `RELAY_SERVICES_*_AUTH_TOKEN` | Relay auth tokens | `openssl rand -base64 16` |
| `SLACK_LEADS_WEBHOOK_URL` | Slack webhook URL | Get from Slack App settings |
| `SLACK_SUPPORT_WEBHOOK_URL` | Slack webhook URL | Get from Slack App settings |

Generate all keys at once (run in CloudShell or terminal):

```bash
echo "ZORD_VAULT_KEY=$(openssl rand -base64 32)"
echo "VAULT_KEY_ID=vault-key-v1"
echo "MASTER_KEY=$(openssl rand -base64 32)"
echo "TOKEN_SECRET=$(openssl rand -base64 32)"
echo "JWT_SIGNING_SECRET=$(openssl rand -base64 32)"
echo "ENCLAVE_INTERNAL_TOKEN=$(openssl rand -base64 32)"
echo "TOKENIZED_DATA_HASH_MASTER_SECRET=$(openssl rand -base64 32)"
echo "INTERNAL_ADMIN_KEY=$(openssl rand -base64 16)"
echo "EDGE_DB_PASSWORD=$(openssl rand -base64 16)"
echo "INTENT_DB_PASSWORD=$(openssl rand -base64 16)"
echo "RELAY_DB_PASSWORD=$(openssl rand -base64 16)"
echo "TOKEN_DB_PASSWORD=$(openssl rand -base64 16)"
echo "OUTCOME_DB_PASSWORD=$(openssl rand -base64 16)"
echo "EVIDENCE_DB_PASSWORD=$(openssl rand -base64 16)"
echo "INTELLIGENCE_DB_PASSWORD=$(openssl rand -base64 16)"
echo "POSTGRES_SUPERUSER_PASSWORD=$(openssl rand -base64 16)"
echo "RELAY_SERVICES_0_AUTH_TOKEN=$(openssl rand -base64 16)"
echo "RELAY_SERVICES_1_AUTH_TOKEN=$(openssl rand -base64 16)"
echo "RELAY_SERVICES_2_AUTH_TOKEN=$(openssl rand -base64 16)"
```

Copy the output → paste into AWS Secrets Manager.

### Step 2: ArgoCD credentials (auto-created)

ArgoCD admin credentials are stored in a **separate** Secrets Manager secret:

```
AWS Console → Secrets Manager → production/zord/argocd-credentials
```

Contains: `username`, `password`, `url` — all auto-generated by Terraform.

Access ArgoCD at: `https://argocd.zordnet.com`

### Step 3: ArgoCD repo access

The GitHub PAT for ArgoCD is passed during `terraform apply` via the `GITHUB_PAT_ARGOCD` GitHub secret. The repo secret is created automatically in the `argocd` namespace — no manual kubectl needed.

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
- `www.zordnet.com` → ALB

> `api.zordnet.com` is handled by the CloudFront edge layer below — do **not** point it directly at the ALB.

## CloudFront + WAF Edge Layer (MNC Security)

Public API traffic flows through a hardened edge before reaching Kong:

```
Internet → CloudFront (caching, DDoS, WAF) → shared ALB → Kong → microservices
```

The edge is a self-contained module (`aws-cloudfront-waf`) and is **fully automatic**:
- Terraform **auto-discovers** the Kong ALB by tag (no hostname to paste)
- Terraform generates the origin-cloaking secret and writes it to Secrets Manager
- Kong reads that secret via External Secrets Operator (already deployed)

### What the edge includes

| Protection | Detail |
|---|---|
| WAF — AWS Common Rule Set | OWASP-class attacks |
| WAF — Known Bad Inputs | Malicious payloads |
| WAF — SQL injection | SQLi rule set |
| WAF — Bot Control | Scrapers, credential stuffing (toggle: `enable_bot_control`) |
| WAF — IP rate limiting | 2000 req / 5 min per IP (DDoS) |
| WAF logging | CloudWatch (auth/cookie headers redacted) |
| Origin cloaking | `X-Origin-Verify` secret header; Kong rejects requests without it |
| Security headers | HSTS (2yr, preload), X-Frame-Options DENY, no-sniff, XSS |
| TLS | 1.2+ viewer→CloudFront and CloudFront→ALB |

### Prerequisite (one-time)

CloudFront **only** accepts ACM certs from `us-east-1`. Issue a second cert there:

```
AWS Console → Certificate Manager → (switch region to N. Virginia / us-east-1)
  → Request public certificate → *.zordnet.com → DNS validation → add the CNAME it shows
```

The ap-south-1 cert still fronts the ALB; the us-east-1 cert is only for CloudFront.

### Self-healing rollout (no manual toggle, no copy-paste)

`ENABLE_CLOUDFRONT_EDGE` defaults to `true` and is safe to leave on. CloudFront's origin needs an ALB that exists, so the edge discovers it automatically:

1. **First apply** — builds the cluster; the app team deploys Kong; the AWS LB Controller creates the shared ALB. If the ALB isn't there yet, the edge quietly skips itself (no failure).
2. **Any later apply** (after Kong exists) — Terraform auto-discovers the ALB by tag, brings up CloudFront + WAF, and writes the origin secret to Secrets Manager. No variable to flip.

### After the edge comes up — DNS

```
Terraform output → cloudfront_domain_name
```

Create the CNAME: `api.zordnet.com` → `<cloudfront_domain_name>`.

### App team — two manifests (their repo, paste once)

The app team adds these to the `api-gateway` namespace so Kong enforces the edge:

**1. Pull the origin secret via External Secrets:**

```yaml
# Uses the app repo's working ESO pattern: v1 API + namespaced SecretStore.
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudfront-origin-verify
  namespace: api-gateway
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: cloudfront-origin-verify
  dataFrom:
    - extract:
        key: production/zord/cloudfront-origin-verify
```

The secret in AWS SM (`production/zord/cloudfront-origin-verify`) exposes these keys:

**CANONICAL CONTRACT (locked with app team — do not rename):**

| JSON key | Value | Consumed as |
|---|---|---|
| `CLOUDFRONT_ORIGIN_VERIFY_HEADER` | `X-Origin-Verify` | header name |
| `CLOUDFRONT_ORIGIN_VERIFY_SECRET` | generated secret | Kong env `CLOUDFRONT_ORIGIN_VERIFY_SECRET` |

**2. Kong plugin — reject anything missing the CloudFront header (blocks ALB bypass):**

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: origin-verify
  annotations:
    kubernetes.io/ingress.class: kong
plugin: pre-function
config:
  access:
    - |
      local secret = os.getenv("CLOUDFRONT_ORIGIN_VERIFY_SECRET")
      local header = kong.request.get_header("X-Origin-Verify")
      if header ~= secret then
        return kong.response.exit(403, { message = "Direct origin access denied" })
      end
```

> Note: the app team's Kong runs **DB-less (declarative configmap)** — no Kong Ingress Controller, so the `KongClusterPlugin` CRD does not apply. They embed the same `pre-function` logic directly in the Kong configmap. Same enforcement. `CLOUDFRONT_ORIGIN_VERIFY_SECRET` is injected into the Kong pod from the `cloudfront-origin-verify` secret above.

**3. After DNS flips**, lock the ALB security group to CloudFront only using the managed prefix list `com.amazonaws.global.cloudfront.origin-facing`.

### Turn the edge off

Set GitHub variable `ENABLE_CLOUDFRONT_EDGE = false` and apply — CloudFront, WAF, and the origin secret are removed. Everything else stays.

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
| **Network** | VPC, 2 public + 2 private subnets, IGW, NAT, routes, security group, S3 VPC endpoint |
| **EKS** | Cluster (v1.32), OIDC provider, access entries |
| **Nodes** | Stateful (t3.xlarge on-demand), Stateless (spot: t3.large/xlarge/m5.large) |
| **Addons** | vpc-cni (NetworkPolicy), coredns, kube-proxy, pod-identity, EBS CSI |
| **Storage** | 3 KMS keys (S3, token-enclave, evidence-archive) + 6 S3 buckets (SSE-KMS, versioned, private) |
| **Security** | 5 per-service S3 IAM roles (PLAT-07), ESO role, autoscaler role, SES role, token-enclave role |
| **Secrets** | 4 AWS Secrets Manager secrets (app-secrets, edge-signing-key, evidence-signing-key, argocd-credentials) |
| **Compute** | EC2 admin (Elastic IP, Jenkins, SonarQube, auto-stop 10PM/start 9AM) |
| **Email** | SES domain (zordnet.com), DKIM, support@ and no-reply@ |
| **Helm** | Cluster Autoscaler, External Secrets Operator + ClusterSecretStore, Argo Rollouts, ArgoCD (with ALB ingress) |
| **GitOps** | ArgoCD repo secret (auto-created from GitHub PAT) |

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
