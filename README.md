# Zord Infrastructure (AWS)

This repo builds the whole AWS platform for Arealis Zord (VPC, EKS, RDS, S3, KMS,
Secrets Manager, CloudFront/WAF, ArgoCD) with **one GitHub Actions workflow**.
The apps themselves are deployed by ArgoCD from the app repo `Arealis-Zord-intent`.

**This README is the single guide.** Follow the steps in order. No theory.

---

## Deploy in one line

```
Do Part A once (setup)  →  Part B: click Apply  →  Part C: build images + click Sync  →  done
```

Deploy order across environments is always: **staging → dev → production**.

---

# PART A — One-time setup (do this ONCE)

You only do Part A the very first time. Skip it after that. Each step below is
click-by-click in the AWS Console. Account: `673698305621` · Region: `ap-south-1` (Mumbai).

---

## Step A1 — Create the S3 bucket for Terraform state

1. Sign in to the **AWS Console**.
2. In the top search bar, type **S3** and click **S3**.
3. Click the orange **Create bucket** button.
4. **Bucket name:** type `zord-infrastructure-aws-tf-state`
5. **AWS Region:** select **Asia Pacific (Mumbai) ap-south-1**.
6. **Block Public Access settings:** leave **Block all public access** CHECKED (all 4 boxes stay ticked).
7. **Bucket Versioning:** click **Enable**.
8. **Default encryption:** choose **Server-side encryption with Amazon S3 managed keys (SSE-S3)**.
9. Scroll down, click **Create bucket**.

> Locking uses the bucket itself (`use_lockfile=true`). You do NOT need DynamoDB.

---

## Step A2 — Add the GitHub login provider (OIDC)

1. In the top search bar, type **IAM** and click **IAM**.
2. In the left menu, click **Identity providers**.
3. Click **Add provider**.
4. **Provider type:** select **OpenID Connect**.
5. **Provider URL:** type `https://token.actions.githubusercontent.com`
6. Click **Get thumbprint**.
7. **Audience:** type `sts.amazonaws.com`
8. Click **Add provider**.

---

## Step A3 — Create the IAM role the workflow uses

1. Still in **IAM**, click **Roles** in the left menu.
2. Click **Create role**.
3. **Trusted entity type:** select **Web identity**.
4. **Identity provider:** choose `token.actions.githubusercontent.com`.
5. **Audience:** choose `sts.amazonaws.com`.
6. Click **Next**.
7. **Permissions:** search and tick **AdministratorAccess** (simplest for a dedicated infra account). Click **Next**.
8. **Role name:** type `zord-infrastructure-aws-role`
9. Click **Create role**.
10. Open the role you just made → find **Maximum session duration** → click **Edit** → set it to **2 hours** → **Save changes**.
11. Click the **Trust relationships** tab → **Edit trust policy** → paste this (change the account/repo if different) → **Update policy**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::673698305621:oidc-provider/token.actions.githubusercontent.com" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
        "StringLike": { "token.actions.githubusercontent.com:sub": "repo:Arealis-network/Zord-Infrastructure-aws:*" }
      }
    }
  ]
}
```

12. At the top of the role page, **copy the Role ARN** (looks like `arn:aws:iam::673698305621:role/zord-infrastructure-aws-role`). You'll paste it into GitHub in Step A7.

---

## Step A4 — Create the DNS zone

1. In the top search bar, type **Route 53** and click **Route 53**.
2. In the left menu, click **Hosted zones**.
3. Click **Create hosted zone**.
4. **Domain name:** type `zordnet.com`
5. **Type:** select **Public hosted zone**.
6. Click **Create hosted zone**.
7. Open the zone → look at the **NS** record → **copy the 4 name server values**.
8. Go to your domain registrar (where you bought `zordnet.com`) and set the domain's name servers to those 4 values. (DNS can take a few hours to update.)

---

## Step A5 — Create the FIRST certificate (ap-south-1, for the load balancer)

1. In the top search bar, type **Certificate Manager** and click it.
2. **Top-right region selector: make sure it says Asia Pacific (Mumbai) ap-south-1.** (If not, click it and change it.)
3. Click **Request a certificate**.
4. Select **Request a public certificate** → click **Next**.
5. **Fully qualified domain name:** type `*.zordnet.com`
6. Click **Add another name to this certificate** → type `zordnet.com` (so the plain domain is covered too).
7. **Validation method:** select **DNS validation - recommended**.
8. **Key algorithm:** leave **RSA 2048**.
9. Click **Request**.
10. On the certificate page, click **Create records in Route 53** → **Create records**. (This works in one click because your hosted zone from A4 exists.)
11. Wait until **Status** shows **Issued** (refresh after a few minutes).

---

## Step A6 — Create the SECOND certificate (us-east-1, for CloudFront)

CloudFront ONLY accepts certificates from the us-east-1 region, so you make a
second one for the same domain.

1. Still in **Certificate Manager**.
2. **Top-right region selector: change it to US East (N. Virginia) us-east-1.** (This is required — CloudFront won't see a cert in any other region.)
3. Click **Request a certificate**.
4. Select **Request a public certificate** → click **Next**.
5. **Fully qualified domain name:** type `*.zordnet.com`
6. **Validation method:** select **DNS validation - recommended**.
7. Click **Request**.
8. On the certificate page, click **Create records in Route 53** → **Create records**.
9. Wait until **Status** shows **Issued**.

> Terraform finds both certs by domain name automatically. You do NOT paste the ARN anywhere.

---

## Step A7 — Add the GitHub secret and variables

1. Open your repo on **GitHub**.
2. Click **Settings** (top menu of the repo).
3. In the left menu, click **Secrets and variables** → **Actions**.

**On the Secrets tab** → click **New repository secret** → add:

| Name | Value | Notes |
|---|---|---|
| `ARGOCD_GITHUB_PAT` | GitHub token with Contents: Read for the app repo | Name must NOT start with `GITHUB_` (reserved by GitHub) |

**On the Variables tab** → click **New repository variable** → add each:

| Name | Value | Notes |
|---|---|---|
| `AWS_ROLE_ARN` | the role ARN copied in Step A3 | e.g. `arn:aws:iam::673698305621:role/zord-infrastructure-aws-role` |
| `TF_STATE_BUCKET` | `zord-infrastructure-aws-tf-state` | the bucket created in Step A1 |

---

## Step A8 — Create the GitHub Environments

1. Still in repo **Settings**, click **Environments** in the left menu.
2. Click **New environment** → type `staging` → **Configure environment**.
3. Repeat for `dev`, then for `production`.
4. Open the **production** environment → under **Required reviewers**, add a lead/manager → **Save**. (Now production runs need approval.)

✅ **Part A done. You never repeat it.**

---

# PART B — Deploy the infrastructure (click Apply)

### Step B1 — Open the workflow
GitHub repo → **Actions** → **Zord Infrastructure** → **Run workflow**

### Step B2 — Choose your options
- **Environment:** `staging` (start here; later `dev`, then `production`)
- **Action:** `apply`
- Click **Run workflow**

### Step B3 — Wait for it to finish (~15–20 min the first time)
When it's done, open the run **Summary**. You'll see:
- The cluster name and domain
- Links: ArgoCD, Grafana, Kibana, Jaeger
- A list of what got created (real AWS data)

**What Apply built:** VPC, EKS, RDS, secrets, ArgoCD, CloudFront/WAF, and it
auto-deployed observability (logging, monitoring, tracing).

**What Apply did NOT do yet:** it did not start your 10 app services or Kong —
those need images first (Part C). This is on purpose.

✅ **Part B done. Cluster is live. Apps not running yet.**

---

# PART C — Deploy the apps (build images, then Sync)

### Step C1 — Build the images (Developer / Jenkins)
Run the Jenkins pipeline for this environment. It builds the 10 service images,
pushes them to ECR, and updates the Helm values (`app.yaml`).

> Until this is done, the app value files contain `PLACEHOLDER` and the platform
> **cannot** be synced. This step is required.

### Step C2 — Open ArgoCD
Use the ArgoCD link from the Part B summary, or:
```
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-stg-eks
```
Login: ArgoCD admin password is in Secrets Manager at `staging/zord/argocd-credentials`.

### Step C3 — Sync the platform (in the ArgoCD UI)
- Click **Sync** on `zord-platform-staging`
- Wait until it turns **Healthy** (all 10 services, Kafka, Redis, migrations up)

### Step C4 — Sync Kong last (in the ArgoCD UI)
- Click **Sync** on `kong-gateway-staging`
- This creates the shared load balancer (ALB)

### Step C5 — It goes live automatically
Once Kong is Healthy, DNS points `api.staging.zordnet.com` at the ALB, and the
CloudFront created in Part B starts serving traffic. **No second Apply needed.**

> Before Kong is up, the public URL returns 502/503. That's normal — it fixes
> itself the moment Kong is Healthy.

✅ **Part C done. The environment is live.**

---

# PART D — Test, then promote

### Step D1 — Run E2E tests against staging (QA)
### Step D2 — If it passes, repeat Parts B + C for `dev`
### Step D3 — Then repeat for `production` (needs the approver to click Approve)

---

# How to destroy an environment (delete everything, stop the bill)

1. Actions → Zord Infrastructure → Run workflow
2. Environment: the one you want to delete
3. Action: `destroy`
4. `confirm_destroy`: type `yes`
5. Run it.

It deletes everything for **that environment only** (reverse order), then shows a
summary of what was removed and confirms nothing billable is left. The shared
state bucket, shared certificate, and apex email identity are kept on purpose.

> This deletes only the selected environment. Other environments are untouched.

---

# Verify the cluster (optional health check)

After Part B, from any machine with AWS access:

```bash
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-stg-eks
kubectl get nodes -o wide          # nodes should be Ready
kubectl get pods -A                # system pods Running/Completed
kubectl get pods -n kube-system | grep -E "coredns|kube-proxy|aws-node|eks-pod-identity-agent|ebs"
```

---

# The 3 environments

| | staging | dev | production |
|---|---|---|---|
| Cluster | `arealis-zord-stg-eks` | `arealis-zord-dev-eks` | `arealis-zord-prod-eks` |
| VPC CIDR | `10.1.0.0/16` | `10.2.0.0/16` | `10.0.0.0/16` |
| Domain | `staging.zordnet.com` | `dev.zordnet.com` | `zordnet.com` |
| App branch | `staging` | `master` | `main` |

Each environment is fully isolated: separate state, network, cluster, domain,
and secrets. Deleting one never affects another.

---

# The 4 workflow actions

| Action | What it does |
|---|---|
| `plan` | Shows what would change. Creates nothing. (Also runs automatically on every Pull Request.) |
| `apply` | Builds all infrastructure + observability + CloudFront. Creates the 5 ArgoCD Applications. |
| `bootstrap` | Optional: a scripted version of Part C. Not needed if you sync in the UI. |
| `destroy` | Deletes the selected environment (needs `confirm_destroy=yes`). |

---

# Who does what (team roles)

| Team | Does |
|---|---|
| Platform / Infra | Parts A, B, D. Runs the workflow. |
| Developer | Part C Step C1 — builds the 10 images in Jenkins. |
| Kubernetes / GitOps | Part C Steps C3–C4 — syncs platform + Kong in ArgoCD. |
| QA | Part D — runs E2E. |
| Lead / Approver | Approves the production run. |

Full operational detail is in [`RUNBOOK.md`](./RUNBOOK.md).

---

# Notes

- Login for AWS uses GitHub OIDC — no static AWS keys stored.
- Secrets are auto-generated by Terraform and stored per environment (`<env>/zord/...`).
  A few (`GEMINI_API_KEYS`, SMTP password, Slack webhooks) say `CHANGE_ME` — set
  those by hand in the Secrets Manager Console once.
- If a secret value ever leaks, rotate it (ask Platform — it's a one-command re-apply of the security component).
