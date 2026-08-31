# Zord Infrastructure — Deployment Guide

Follow these steps in order. The whole AWS platform (EKS, VPC, IAM, S3, KMS,
Secrets Manager, CloudFront/WAF, ArgoCD, External Secrets) is created by ONE
GitHub Actions workflow. The application itself is deployed by ArgoCD from the
app repo (`Arealis-Zord-intent`).

---

## Deployment order at a glance

```
0. One-time prerequisites (OIDC role, state bucket, 2 ACM certs, GitHub secrets)
1. Run the infrastructure workflow  → action: apply   (cluster + all AWS resources)
2. Fill in the CHANGE_ME secret values in AWS Secrets Manager
3. App/K8s team deploys the app + Kong via ArgoCD  → shared ALB is created
4. Run the infrastructure workflow again  → CloudFront + WAF auto-come-up
5. Point DNS (api → CloudFront, everything else → ALB)
6. Verify from the Bastion (EC2 admin)
```

CloudFront needs the Kong ALB to exist, so it comes up on the second apply
(step 4). This is automatic and self-healing — no manual toggle.

---

## Step 0 — One-time prerequisites

**📄 Full click-by-click AWS Console instructions are in [`manual.md`](./manual.md).**
Do everything in that file once, then come back to Step 1.

Summary of what `manual.md` creates in the AWS account (`673698305621`, `ap-south-1`):

| Requirement | Where to create |
|---|---|
| S3 Terraform state bucket | S3 → `zord-infrastructure-aws-tf-state` (versioned, encrypted, private) |
| DynamoDB lock table | DynamoDB → `zord-infrastructure-aws-tf-lock` (partition key `LockID`) |
| OIDC Identity Provider | IAM → Identity providers → `token.actions.githubusercontent.com` |
| IAM Role for GitHub Actions | IAM → Roles → `zord-infrastructure-aws-role` (OIDC trust, 2h max session) |
| Route 53 hosted zone | Route 53 → `zordnet.com` (delegate NS at registrar) |
| ACM cert (ALB) | ACM in **ap-south-1** → `*.zordnet.com` — must be ISSUED |
| ACM cert (CloudFront) | ACM in **us-east-1** → `*.zordnet.com` — CloudFront ONLY accepts us-east-1 certs |
| GitHub secrets + variables | See `manual.md` §8 |

> You need **two** `*.zordnet.com` certs — one in ap-south-1 (for the ALB) and
> one in us-east-1 (for CloudFront). Both are free and DNS-validated.

### GitHub repository secrets

`Repo → Settings → Secrets and variables → Actions → Secrets`

Only the PAT is truly sensitive. The role ARN and bucket name are not secrets —
they go in **Variables** below.

| Secret | Value |
|---|---|
| `ARGOCD_GITHUB_PAT` | GitHub Personal Access Token (ArgoCD reads the app repo). Name must NOT start with `GITHUB_` — GitHub reserves that prefix. |

### GitHub repository variables

`Repo → Settings → Secrets and variables → Actions → Variables`

| Variable | Default | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | — (required) | `arn:aws:iam::673698305621:role/zord-infrastructure-aws-role` |
| `TF_STATE_BUCKET` | — (required) | `zord-infrastructure-aws-tf-state` |
| `TF_LOCK_TABLE` | — (required) | `zord-infrastructure-aws-tf-lock` (DynamoDB state lock) |
| `ZORD_DOMAIN` | `zordnet.com` | Root domain. Drives SES, ACM lookup, CloudFront entrypoint (`api.<domain>`). |
| `ENABLE_CLOUDFRONT_EDGE` | `true` | CloudFront + WAF master switch. Self-healing — safe to leave on. |
| `KONG_ALB_STACK_TAG` | `zord-shared-alb` | ALB group tag the AWS LB Controller sets. Used to auto-discover the ALB. |

Change the domain later = edit `ZORD_DOMAIN` only. No code change.

---

## Step 1 — Deploy the infrastructure (one click)

```
GitHub Actions → Zord Infrastructure → Run workflow
    Environment: production   (or staging)
    Action:      apply
```

One `terraform apply` creates everything:

```
VPC → EKS Cluster → Node Groups → Core Addons → EBS CSI → 3 KMS Keys →
6 S3 Buckets → Per-Service Pod-Identity IAM → 13 Secrets Manager secrets →
EC2 Admin (Jenkins + SonarQube) → SES → Cluster Autoscaler →
External Secrets Operator + ClusterSecretStore → Argo Rollouts →
ArgoCD → CloudFront + WAF (skips itself until Kong's ALB exists)
```

Wait until the workflow finishes. The **apply summary** shows every resource
created, a per-module count, and Bastion verification commands. On this first
run CloudFront shows `⏸️ Skipped (Kong ALB not found yet)` — that is expected.

---

## Step 2 — Fill in the secret values (AWS Console, one-time)

Infra creates 13 per-service secrets pre-filled with `CHANGE_ME`. Replace the
placeholders with real values.

```
AWS Console → Secrets Manager → production/zord/<name> → Retrieve secret value → Edit
```

Secrets and who uses them:

| Secret | Service |
|---|---|
| `production/zord/shared-infra` | all (DB host, KMS ARNs — some auto-filled) |
| `production/zord/edge-secrets` | zord-edge |
| `production/zord/intent-engine-secrets` | zord-intent-engine |
| `production/zord/token-enclave-secrets` | zord-token-enclave |
| `production/zord/relay-secrets` | zord-relay |
| `production/zord/outcome-engine-secrets` | zord-outcome-engine |
| `production/zord/evidence-secrets` | zord-evidence |
| `production/zord/intelligence-secrets` | zord-intelligence |
| `production/zord/prompt-layer-secrets` | zord-prompt-layer |
| `production/zord/console-secrets` | zord-console |
| `production/zord/edge-signing-key` | zord-edge (ed25519 PEM) |
| `production/zord/evidence-signing-key` | zord-evidence (PEM) |
| `production/zord/cloudfront-origin-verify` | Kong — **auto-generated, do NOT edit** |

**Auto-populated by Terraform (leave as-is):** `S3_KMS_KEY_ID`,
`ACM_CERTIFICATE_ARN`, `EVIDENCE_KMS_KEY_ARN`, `KMS_KEY_ID`, all `*_S3_BUCKET`
keys, and the entire `cloudfront-origin-verify` secret.

**Signing keys:** in `edge-signing-key` and `evidence-signing-key`, replace
`CHANGE_ME` with your real PEM (use `\n` for newlines).

Generate random values (run in CloudShell or any terminal):

```bash
# keys / tokens (32-byte base64)
openssl rand -base64 32
# database passwords (16-byte base64)
openssl rand -base64 16
```

Fill in: all `*_DB_PASSWORD`, `ZORD_VAULT_KEY`, `VAULT_KEY_ID`,
`TOKEN_SECRET`, `JWT_SIGNING_SECRET`, `SERVICE_JWT_SIGNING_SECRET`,
`ENCLAVE_INTERNAL_TOKEN`, `TOKENIZED_DATA_HASH_MASTER_SECRET`,
`INTERNAL_ADMIN_KEY`, all `RELAY_*_AUTH_TOKEN`, `GEMINI_API_KEYS`,
`SLACK_*_WEBHOOK_URL`, `POSTGRES_SUPERUSER_PASSWORD`.

### ArgoCD login (auto-created — no edit)

```
AWS Console → Secrets Manager → production/zord/argocd-credentials
```

Contains `username` / `password` / `url`, all auto-generated. ArgoCD is at
`https://argocd.zordnet.com`. The ArgoCD repo secret is created automatically
from `ARGOCD_GITHUB_PAT` — no manual kubectl.

---

## Step 3 — App/K8s team deploys the application (GitOps via ArgoCD)

The application is deployed by **ArgoCD**, not by manual `kubectl apply`. The
app team pushes manifests to the app repo (`Arealis-Zord-intent`, branch
`master`) and ArgoCD auto-syncs them. Sync waves handle ordering
(Postgres/Kafka first, then services, then Kong).

Deploying Kong creates the **shared internet-facing ALB** (group
`zord-shared-alb`). That ALB is what CloudFront will front.

You (infra) can watch progress:

```bash
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-prod-eks
kubectl get applications -n argocd
kubectl get pods -n zord -w
kubectl get ingress -n api-gateway     # ALB appears once Kong syncs
```

> Manual `kubectl apply -k` is only a fallback for a non-GitOps deploy. If
> ArgoCD is running with auto-sync, do NOT apply by hand — it fights the sync.

---

## Step 4 — Bring up CloudFront + WAF (one click, automatic)

Once Kong's ALB exists, run the workflow again:

```
GitHub Actions → Zord Infrastructure → Run workflow
    Environment: production
    Action:      apply
```

Terraform auto-discovers the ALB (by tag `zord-shared-alb`), then creates:
- CloudFront distribution fronting the ALB
- WAF WebACL (Common + Known-Bad-Inputs + SQLi + Bot Control + IP rate-limit)
- WAF logging to CloudWatch (auth/cookie headers redacted)
- Security response headers (HSTS, X-Frame-Options DENY, no-sniff, XSS)
- The origin-cloaking secret in Secrets Manager (Kong reads it via ESO)

No manual hostname, no variable to flip. The apply summary now shows CloudFront
`✅ Active` with its domain name.

---

## Step 5 — DNS

Get the values:

```bash
kubectl get ingress -n api-gateway                 # ALB DNS name
# infra apply summary → cloudfront_domain_name      # CloudFront domain
```

Create CNAME records at your DNS provider:

| Host | Points to |
|---|---|
| `api.zordnet.com` | CloudFront domain (`dxxxx.cloudfront.net`) |
| `zordnet.com` | ALB DNS |
| `www.zordnet.com` | ALB DNS |
| `kong-admin.zordnet.com` | ALB DNS (keep OFF CloudFront) |

Only `api.` goes through CloudFront. `kong-admin` must never be on the public
edge.

---

## Step 6 — Verify from the Bastion (EC2 admin)

SSH into the EC2 admin instance (IP is in the apply summary), then run the
verification commands the summary prints. Quick set:

```bash
# cluster
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-prod-eks
kubectl get nodes -o wide
kubectl get pods -A
helm list -A

# controllers
kubectl get pods -n external-secrets
kubectl get clustersecretstore,secretstore -A
kubectl get pods -n argocd
kubectl get pods -n argo-rollouts

# AWS resources (counts should match the apply summary tables)
aws s3api list-buckets --query "Buckets[?starts_with(Name,'zord-')].Name" --output text
aws secretsmanager list-secrets --region ap-south-1 --filters Key=name,Values=production/zord --query 'SecretList[*].Name' --output text
aws iam list-roles --query "Roles[?starts_with(RoleName,'arealis-zord')].RoleName" --output text

# edge
aws cloudfront list-distributions --query "DistributionList.Items[?contains(Comment,'arealis-zord')].[Id,DomainName,Status]" --output table
aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1 --query "WebACLs[?contains(Name,'arealis-zord')].[Name,Id]" --output table

# ArgoCD password
aws secretsmanager get-secret-value --secret-id production/zord/argocd-credentials --region ap-south-1 --query SecretString --output text | jq .
```

---

## CloudFront + WAF edge — how it works

```
Internet → CloudFront (caching, DDoS, WAF) → shared ALB → Kong → microservices
```

Self-contained module `aws-cloudfront-waf`, fully automatic:
- Auto-discovers the Kong ALB by tag (no hostname to paste)
- Generates the origin-cloaking secret → Secrets Manager
- Kong reads it via External Secrets Operator

| Protection | Detail |
|---|---|
| WAF — AWS Common Rule Set | OWASP-class attacks |
| WAF — Known Bad Inputs | Malicious payloads |
| WAF — SQL injection | SQLi rule set |
| WAF — Bot Control | Scrapers, credential stuffing (toggle `enable_bot_control`) |
| WAF — IP rate limiting | 2000 req / 5 min per IP (DDoS) |
| WAF metrics | CloudWatch metrics only (near-zero cost) → view in Grafana via CloudWatch data source. No CloudWatch Logs (dropped to avoid log-ingestion cost). |
| Origin cloaking | `X-Origin-Verify` header; Kong 403s requests without it |
| Security headers | HSTS (2yr, preload), X-Frame-Options DENY, no-sniff, XSS |
| TLS | 1.2+ viewer→CloudFront and CloudFront→ALB |

### Origin-verify contract (LOCKED with app team — do not rename)

Secret `production/zord/cloudfront-origin-verify`:

| JSON key | Value | Consumed as |
|---|---|---|
| `CLOUDFRONT_ORIGIN_VERIFY_HEADER` | `X-Origin-Verify` | header name |
| `CLOUDFRONT_ORIGIN_VERIFY_SECRET` | generated secret | Kong env `CLOUDFRONT_ORIGIN_VERIFY_SECRET` |

App team side (their repo): an ExternalSecret (`external-secrets.io/v1` +
namespaced `SecretStore aws-secretsmanager`, `dataFrom: extract`) pulls this
secret, and a Kong `pre-function` in the declarative configmap 403s any request
whose `X-Origin-Verify` header ≠ the secret. They ship log-only first, then flip
to enforce after DNS points at CloudFront.

### Lock the origin after go-live

Once `api.zordnet.com` resolves to CloudFront, lock the ALB security group to
the CloudFront managed prefix list `com.amazonaws.global.cloudfront.origin-facing`
so the ALB accepts CloudFront traffic only.

### Turn the edge off

Set `ENABLE_CLOUDFRONT_EDGE = false` and apply — CloudFront, WAF, and the origin
secret are removed. Everything else stays.

---

## Access

| Service | URL |
|---|---|
| ArgoCD | `https://argocd.zordnet.com` (creds in `production/zord/argocd-credentials`) |
| Jenkins | `http://<EC2_ELASTIC_IP>:7777` |
| SonarQube | `http://<EC2_ELASTIC_IP>:7771` |
| EKS | `aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-prod-eks` |

`ec2_public_ip` is in the apply summary.

---

## Destroy (one click)

```
GitHub Actions → Zord Infrastructure → Run workflow
    Environment: production
    Action:      destroy
    confirm_destroy: yes
```

Automated cleanup: webhooks + finalizers → Helm uninstall → delete
LoadBalancer services + Ingresses + PVCs → wait 90s → `terraform destroy` →
retry with ENI/SG cleanup if needed → verify every AWS resource is gone (13
checks) with real-time billing.

---

## What gets created (per environment)

| Category | Resources |
|---|---|
| **Network** | VPC, 2 public + 2 private subnets, IGW, NAT, routes, SG, S3 VPC endpoint |
| **EKS** | Cluster (v1.32), OIDC provider, access entries |
| **Nodes** | Stateful (t3.xlarge on-demand), Stateless (spot) |
| **Addons** | vpc-cni (NetworkPolicy), coredns, kube-proxy, pod-identity, EBS CSI |
| **Storage** | 3 KMS keys (S3, token-enclave, evidence-archive) + 6 S3 buckets (SSE-KMS, versioned, private) |
| **Security** | Per-service Pod-Identity IAM roles (PLAT-07), ESO, autoscaler, SES, token-enclave, evidence roles |
| **Secrets** | 13 per-service Secrets Manager secrets + argocd-credentials + cloudfront-origin-verify |
| **Compute** | EC2 admin (Elastic IP, Jenkins, SonarQube, auto-stop 10PM/start 9AM) |
| **Email** | SES domain, DKIM, support@ / no-reply@ |
| **Edge** | CloudFront distribution + WAF WebACL + WAF logging (comes up once Kong ALB exists) |
| **Helm** | Cluster Autoscaler, External Secrets Operator + ClusterSecretStore, Argo Rollouts, ArgoCD |

---

## Module structure

```
EKS-terraform/modules/
├── aws-vpc/                    ← VPC + subnets + NAT + routes + SG + S3 endpoint
├── aws-eks-cluster/            ← EKS + OIDC + cluster IAM role
├── aws-eks-node-groups/        ← Node groups + worker IAM role
├── aws-eks-addons/             ← Core addons (vpc-cni, coredns, kube-proxy, pod-identity)
├── aws-ebs-csi/                ← EBS CSI IAM + pod identity + addon
├── aws-ec2-admin/              ← EC2 + EIP + scheduler + tool.sh
├── aws-ses-email/              ← SES + IAM + pod identity
├── aws-kms/                    ← KMS key for S3 encryption
├── aws-kms-token-enclave/      ← KMS key for PII (TOK-03)
├── aws-kms-evidence-archive/   ← KMS key for evidence envelope encryption (NEW-P1-06)
├── aws-s3-buckets/             ← 6 private buckets (SSE-KMS, versioned)
├── aws-s3-access/              ← Per-service IAM roles (PLAT-07 least privilege)
├── aws-secrets-manager/        ← 13 per-service secrets, pre-filled
├── aws-cloudfront-waf/         ← CloudFront + WAF + origin cloaking (edge layer)
├── helm-cluster-autoscaler/    ← IAM + pod identity + Helm
├── helm-external-secrets/      ← IAM + pod identity + Helm + ClusterSecretStore
├── helm-argo-rollouts/         ← Argo Rollouts controller
└── helm-argocd/                ← ArgoCD + ALB ingress + credentials + repo secret
```

---

## Security features

| Feature | Status |
|---|---|
| GitHub OIDC (no static AWS keys) | ✅ |
| EKS Pod Identity (not IRSA) | ✅ |
| Per-service IAM (PLAT-07 least privilege) | ✅ |
| KMS encryption on all S3 buckets | ✅ |
| CloudFront + WAF edge (OWASP, SQLi, bot, rate-limit) | ✅ |
| Origin cloaking (no direct-to-ALB bypass) | ✅ |
| Security headers (HSTS, anti-clickjacking) | ✅ |
| NetworkPolicy enforcement (VPC CNI) | ✅ |
| IMDSv2 enforced on all nodes | ✅ |
| EKS private + public endpoint | ✅ |
| Secrets never in Terraform state | ✅ |
| S3 versioning + public access fully blocked | ✅ |
| EC2 restricted security group (22, 7777, 7771 only) | ✅ |
| KMS key auto-rotation | ✅ |

---

## Cross-team contracts (don't drift)

- ServiceAccount names must match Pod Identity associations (no IRSA annotations)
- Per-service secret JSON keys must match what each deployment reads
- `cloudfront-origin-verify` keys are LOCKED: `CLOUDFRONT_ORIGIN_VERIFY_HEADER` / `CLOUDFRONT_ORIGIN_VERIFY_SECRET`
- ALB group tag `zord-shared-alb`; Kong namespace `api-gateway`
- ArgoCD app targetRevision (branch) = `master`
- Any change to a shared name goes through infra first
