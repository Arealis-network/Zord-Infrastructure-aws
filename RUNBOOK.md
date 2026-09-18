# Zord Infrastructure Runbook

Operational guide for deploying and operating the Arealis Zord platform across
`staging`, `dev`, and `production`. This is the document each team follows so
everyone knows their part. It describes **who** runs **what**, in **what order**.

---

## 1. Repositories and ownership

Two repositories, two ownership boundaries. Neither team edits the other's repo.

| Repository | Owns | Team |
|---|---|---|
| `Zord-Infrastructure-aws` (this repo) | Terraform (VPC, EKS, RDS, KMS, S3, secrets, ArgoCD install), the GitHub Actions workflow, AWS account wiring | Platform / Infra |
| `Arealis-Zord-intent` (app repo) | Microservice code, Dockerfiles, Helm charts (incl. the `zord-app` umbrella chart), per-env values, Jenkins pipelines, ArgoCD manifests, E2E tests | Developers + Kubernetes/GitOps |

Infra only *references* the app repo (ArgoCD reads it). Infra never contains app code.

---

## 2. Roles

| Role | Responsibility |
|---|---|
| **Platform / Infra engineer** | Runs the GitHub workflow (`plan` / `apply` / `destroy`), manages Terraform state, IAM, networking, secrets. |
| **Developer** | Writes service code, opens PRs. Triggers Jenkins to build the 10 service images and update Helm values. |
| **Kubernetes / GitOps / SRE** | Owns ArgoCD and the cluster. Performs the manual ArgoCD UI syncs (`zord-platform`, `kong-gateway`), watches rollout health. |
| **Approver (lead / release manager)** | Approves the GitHub Environment gate before a production apply/destroy. |
| **QA** | Runs and signs off end-to-end tests in staging/dev before promotion. |

No single person holds all access. Separation of duties is enforced by branch
protection and GitHub Environment approvals (see Section 8).

---

## 3. Environments

| | staging | dev | production |
|---|---|---|---|
| Cluster | `arealis-zord-stg-eks` | `arealis-zord-dev-eks` | `arealis-zord-prod-eks` |
| VPC CIDR | `10.1.0.0/16` | `10.2.0.0/16` | `10.0.0.0/16` |
| Domain | `staging.zordnet.com` | `dev.zordnet.com` | `zordnet.com` |
| App branch | `staging` | `master` | `main` |
| Values dir | `kubernetes/values/staging` | `kubernetes/values/dev` | `kubernetes/values/prod` |
| ArgoCD mode | `helm` | `helm` | `legacy` (until promoted) |
| State keys | `eks/staging/*.tfstate` | `eks/dev/*.tfstate` | `eks/production/*.tfstate` |

**Golden rule:** deploy order is always **staging → dev → production**. Never
deploy production before staging and dev have passed E2E.

---

## 4. The six components

Infra is split into six independently state-locked Terraform roots under
`live/components/`, applied in order:

| # | Component | Creates |
|---|---|---|
| 01 | `01-foundation` | VPC, subnets, NAT, flow logs, base KMS |
| 02 | `02-data` | S3 buckets, RDS Postgres, evidence/token KMS keys, `db-connection` secret |
| 03 | `03-compute` | EKS cluster, node groups, core addons, bastion |
| 04 | `04-security` | Per-service IAM + Pod Identity, all service secrets, SES |
| 05 | `05-platform` | EBS CSI, autoscaler, ALB controller, External DNS, ESO, Rollouts, ArgoCD + the 5 Application definitions |
| 06 | `06-edge` | CloudFront + WAF (origin = `api.<env_domain>`) |

Apply runs 01→06. Destroy runs 06→01.

---

## 5. Workflow actions

Run from GitHub → Actions → **Zord Infrastructure** → Run workflow.

| Action | What it does | Who runs it |
|---|---|---|
| `plan` | Dry run across all 6 components. Creates nothing. Also runs automatically on every PR. | Platform |
| `apply` | Creates all infra + observability + CloudFront in one pass. Creates the 5 ArgoCD Applications (platform/Kong left manual). | Platform |
| `bootstrap` | Optional scripted alternative that syncs the apps for you. Not needed in the standard flow. | Platform (fallback only) |
| `destroy` | Reverse-order teardown with typed `confirm_destroy=yes` gate + live residual verification. | Platform (with approval) |

---

## 6. Standard deployment flow (per environment)

This is the day-to-day sequence. It is **one `apply`, no waits, no second apply.**

```
STEP 1 — Developer: open PR in the app repo, merge to the env branch (staging/master/main).
STEP 2 — Platform: run the workflow, action = apply, environment = <env>.
           → Infra + observability (logging/monitoring/tracing) + CloudFront all created.
           → Summary shows ArgoCD / Grafana / Kibana / Jaeger links + the public URL.
STEP 3 — Developer: run Jenkins for <env>.
           → Builds the 10 service images, pushes to ECR, updates app.yaml (clears the PLACEHOLDER gate).
STEP 4 — Kubernetes/GitOps: open ArgoCD UI.
           → Sync zord-platform-<env>  → wait until Healthy
           → Sync kong-gateway-<env>   (last)
STEP 5 — Automatic: once Kong is Healthy, External DNS points api.<env_domain> at the
           shared ALB, and the already-created CloudFront starts serving traffic.
STEP 6 — QA: run E2E against <env>. Sign off.
STEP 7 — Promote: repeat for the next environment (staging → dev → production).
```

### Why platform + Kong are manual
They depend on the 10 Jenkins-built images. Auto-deploying them before the images
exist would crash-loop against `PLACEHOLDER` tags. A human clicks Sync in ArgoCD
once the images are real — this is the safety gate that protects user traffic.

### Why there is no wait / no second apply
CloudFront's origin is the stable hostname `api.<env_domain>`, not the live ALB
DNS. So Terraform creates CloudFront on the first apply. Until Kong is synced the
public URL returns 502/503 (expected); the moment Kong is Healthy and DNS resolves,
it serves traffic automatically.

### Observability auto-sync preference
Whether logging/monitoring/tracing auto-sync on `apply` is controlled by
`platform.observability_auto_sync_on_apply` in each env's `config.json`:
- `staging` / `dev`: `true` — observability deploys automatically on apply.
- `production`: `false` — deployed via the manual/gated flow.

If the Kubernetes/GitOps team prefers to watch the very first staging sync
manually, set staging's flag to `false`, apply, then sync logging → monitoring →
tracing by hand in the ArgoCD UI before syncing platform. Record the agreed
preference here and mirror it in the app repo's `ARGOCD-INFRA-HANDOFF.md`.

---

## 7. Destroying an environment

```
Platform: run the workflow, action = destroy, environment = <env>, confirm_destroy = yes.
  1. Kubernetes cleanup first (delete ingresses + PVCs, strip ArgoCD finalizers) so ALB/EBS are removed.
  2. Reverse-order destroy 06 → 01.
  3. Live-AWS verification: queries EKS/VPC/NAT/EIP/RDS/EC2/S3 scoped to THIS env's cluster tag only.
     Reports a clean-destroy result or lists any residual billable resource.
```

Retained on purpose (shared, not billed to the destroyed env's compute):
the Terraform state bucket, the shared ACM cert, the apex SES identity.
The summary never claims the whole AWS account bill is zero — only that this
environment's resources were removed.

---

## 8. Required GitHub setup (one-time, Platform lead)

The workflow fails at start without these.

**Repository variables** (Settings → Secrets and variables → Actions → Variables):
- `AWS_ROLE_ARN` — the OIDC IAM role the workflow assumes
- `TF_STATE_BUCKET` — the S3 bucket holding all environment state

**Repository secret**:
- `ARGOCD_GITHUB_PAT` — PAT ArgoCD uses to read the app repo

**GitHub Environments** (Settings → Environments) — create `production`, `staging`, `dev`:
- On `production`, add **required reviewers** so a human must approve before any
  production apply/destroy runs. This is the change-control gate.

**Branch protection** (Settings → Branches) on `main` / `master` / `staging`:
- Require a pull request before merging
- Require approvals (at least one reviewer)
- Require the `validate` status check to pass before merge

These two settings turn the workflow from "anyone can run it" into
"reviewed, approved, and audited" — the MNC standard.

---

## 9. Change control for production

Production is live. Follow this every time:

1. Staging **and** dev must have passed E2E first.
2. Open a change request with a maintenance window and a rollback plan.
3. Production stays on `legacy` ArgoCD mode until Helm is explicitly promoted.
4. The GitHub Environment approver must approve the run.
5. After apply + sync, verify API traffic, data integrity, observability, DNS,
   CloudFront/WAF, and E2E before declaring done.

---

## 10. Security notes

- Authentication is GitHub OIDC — no static AWS keys are stored.
- Secrets are generated by Terraform (`random_password` / `random_bytes`) and
  written to Secrets Manager per environment (`<env>/zord/...`). External Secrets
  Operator syncs them into the cluster; the `ClusterSecretStore` is owned by the
  app team's umbrella chart (PreSync, wave −5).
- Never paste secret values into chat, tickets, or commits. If a secret is
  exposed, rotate it: taint the specific `random_password` resource in the
  affected environment's `04-security` state and re-apply that component only.
- Each service gets its own IAM role scoped to only its buckets/keys
  (least privilege). A compromised pod cannot reach another service's data.

---

## 11. Quick reference

```
Deploy an env:   Actions → Zord Infrastructure → apply (env)   → Jenkins → ArgoCD UI sync platform, then Kong
Plan only:       Actions → Zord Infrastructure → plan (env)     (also auto-runs on PRs)
Tear down:       Actions → Zord Infrastructure → destroy (env), confirm_destroy = yes
Cluster access:  aws eks update-kubeconfig --region ap-south-1 --name <cluster>
Order always:    staging → dev → production
```
