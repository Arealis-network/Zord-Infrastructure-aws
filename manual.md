# Manual One-Time Setup (AWS Console)

These resources must exist **before** the first `terraform apply`. They are the
bootstrap layer — Terraform can't create the bucket that stores its own state,
the role it assumes, or the certs it looks up. Do these once per AWS account,
using the AWS Console UI (no CLI needed).

Account: `673698305621` · Primary region: `ap-south-1` (Mumbai)

Order:
```
1. S3 bucket (Terraform state)
2. DynamoDB lock table (state locking)
3. GitHub OIDC identity provider
4. IAM role for GitHub Actions (OIDC)
5. Route 53 hosted zone (DNS)
6. ACM certificate — ap-south-1 (for the ALB)
7. ACM certificate — us-east-1 (for CloudFront)
8. GitHub repository secrets & variables
```

> State locking uses **DynamoDB**. The workflow pins Terraform 1.10.5 so the
> `dynamodb_table` backend option stays warning-free.

---

## 1. S3 bucket — Terraform state

Stores `terraform.tfstate` remotely so the workflow is stateless and safe.

1. AWS Console → **S3** → **Create bucket**
2. **Bucket name:** `zord-infrastructure-aws-tf-state`
3. **Region:** Asia Pacific (Mumbai) `ap-south-1`
4. **Block Public Access:** leave ALL four boxes **checked** (fully private)
5. **Bucket Versioning:** **Enable** (lets you recover a corrupted/old state)
6. **Default encryption:** **Enable** → SSE-S3 (or SSE-KMS if you prefer)
7. Create bucket.

> The workflow reads this via the GitHub secret `TF_STATE_BUCKET`. State keys are
> per environment: `eks/production/terraform.tfstate`, `eks/staging/terraform.tfstate`.

---

## 2. DynamoDB lock table — Terraform state locking

Prevents two applies from corrupting the state at the same time.

1. AWS Console → **DynamoDB** → **Create table**
2. **Table name:** `zord-infrastructure-aws-tf-lock`
3. **Partition key:** `LockID` — type **String** (the name must be exactly `LockID`)
4. **Table settings:** Default settings (On-demand capacity)
5. **Create table.**

> Referenced by the GitHub variable `TF_LOCK_TABLE`, passed to `terraform init`
> via `-backend-config="dynamodb_table=..."`.

---

## 3. GitHub OIDC identity provider

Lets GitHub Actions authenticate to AWS with short-lived tokens — no static keys.

1. AWS Console → **IAM** → **Identity providers** → **Add provider**
2. **Provider type:** OpenID Connect
3. **Provider URL:** `https://token.actions.githubusercontent.com`
   → click **Get thumbprint**
4. **Audience:** `sts.amazonaws.com`
5. **Add provider.**

---

## 4. IAM role for GitHub Actions (OIDC)

The role the workflow assumes to build infrastructure.

1. AWS Console → **IAM** → **Roles** → **Create role**
2. **Trusted entity type:** Web identity
3. **Identity provider:** `token.actions.githubusercontent.com`
4. **Audience:** `sts.amazonaws.com`
5. Continue, then **edit the trust policy** to lock it to your repo. Use this
   (replace the account ID / org / repo if different):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::673698305621:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Arealis-network/Zord-Infrastructure-aws:*"
        }
      }
    }
  ]
}
```

6. **Permissions:** attach a policy that lets Terraform manage the stack.
   Fastest for a dedicated infra account: `AdministratorAccess`. For tighter
   control, scope it to EKS, EC2, VPC, IAM, S3, KMS, Secrets Manager, SES,
   CloudFront, WAFv2, ELB, CloudWatch Logs, EventBridge Scheduler.
7. **Role name:** `zord-infrastructure-aws-role`
8. Create role, then copy its **ARN**:
   `arn:aws:iam::673698305621:role/zord-infrastructure-aws-role`

> **Max session duration:** open the role → Edit → set **Maximum session duration
> = 2 hours**. The apply/destroy jobs request a 2h session.

---

## 5. Route 53 hosted zone (DNS)

Manages DNS for `zordnet.com` so you can point records at the ALB and CloudFront.

1. AWS Console → **Route 53** → **Hosted zones** → **Create hosted zone**
2. **Domain:** `zordnet.com`
3. **Type:** Public hosted zone
4. Create it, then copy the **4 NS (name server) records**.
5. At your domain registrar (where you bought `zordnet.com`), set the domain's
   name servers to those 4 values. DNS propagation can take up to a few hours.

> You'll come back here after deploy to add CNAMEs: `api.` → CloudFront,
> `zordnet.com` / `www.` / `kong-admin.` → ALB.

---

## 6. ACM certificate — ap-south-1 (for the ALB)

The wildcard cert the shared ALB uses to terminate TLS.

1. AWS Console → **Certificate Manager** → region **Asia Pacific (Mumbai)
   ap-south-1**
2. **Request** → **Request a public certificate**
3. **Fully qualified domain name:** `*.zordnet.com`
   (add a second name `zordnet.com` if you want the apex covered)
4. **Validation method:** DNS validation
5. Request, then open the cert → **Create records in Route 53** (one click, since
   the hosted zone exists). Wait until **Status = Issued**.

> Terraform auto-discovers this cert by domain — you don't paste the ARN.

---

## 7. ACM certificate — us-east-1 (for CloudFront)

CloudFront **only** accepts certs from `us-east-1`. This is a separate cert from
the ap-south-1 one, for the same domain.

1. AWS Console → **Certificate Manager** → switch region to **US East (N.
   Virginia) us-east-1**
2. **Request** → **Request a public certificate**
3. **Fully qualified domain name:** `*.zordnet.com`
4. **Validation method:** DNS validation
5. Request, then **Create records in Route 53**. Wait until **Status = Issued**.

> Without this cert, the CloudFront part of `apply` will fail when the edge tries
> to enable. Do this before running the edge (step 4 of deploy.md).

---

## 8. GitHub repository secrets & variables

`GitHub repo → Settings → Secrets and variables → Actions`

### Secrets tab

Only the PAT is sensitive. The role ARN and bucket name are NOT secrets — put
them in the Variables tab.

| Secret | Value |
|---|---|
| `ARGOCD_GITHUB_PAT` | GitHub Personal Access Token (Contents: Read) for the app repo. **Name must NOT start with `GITHUB_`** — GitHub reserves that prefix. |

### Variables tab

| Variable | Value / Default | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::673698305621:role/zord-infrastructure-aws-role` | Role the workflow assumes (required) |
| `TF_STATE_BUCKET` | `zord-infrastructure-aws-tf-state` | Terraform state bucket (required) |
| `TF_LOCK_TABLE` | `zord-infrastructure-aws-tf-lock` | DynamoDB state lock table (required) |
| `ZORD_DOMAIN` | `zordnet.com` | Root domain |
| `ENABLE_CLOUDFRONT_EDGE` | `true` | CloudFront + WAF master switch (self-healing) |
| `KONG_ALB_STACK_TAG` | `zord-shared-alb` | ALB group tag for auto-discovery |

---

## Checklist before first apply

- [ ] S3 state bucket exists, versioned, private
- [ ] DynamoDB lock table `zord-infrastructure-aws-tf-lock` (partition key `LockID`)
- [ ] GitHub OIDC provider added
- [ ] IAM role `zord-infrastructure-aws-role` created, trust locked to the repo, 2h max session
- [ ] Route 53 hosted zone for `zordnet.com` created and NS delegated at registrar
- [ ] ACM cert `*.zordnet.com` **ISSUED in ap-south-1**
- [ ] ACM cert `*.zordnet.com` **ISSUED in us-east-1**
- [ ] GitHub variables `AWS_ROLE_ARN`, `TF_STATE_BUCKET` set
- [ ] GitHub secret `ARGOCD_GITHUB_PAT` set

Once every box is checked, return to `deploy.md` → **Step 1 — Deploy the
infrastructure**.
