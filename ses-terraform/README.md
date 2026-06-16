# SES Terraform — Email OTP MFA

This folder sets up AWS SES so your EKS pods can send OTP verification emails.

## What It Creates

- SES domain identity (`zordnet.com`)
- DKIM configuration (email authentication)
- MAIL FROM subdomain (`mail.zordnet.com`)
- IAM policy allowing `ses:SendEmail` and `ses:SendRawEmail`
- IAM role with EKS Pod Identity trust
- Pod identity association linking the role to your workload service account

## End-To-End Deployment (Step By Step)

Follow these steps exactly in this order.

---

### Step 1: Make sure your EKS cluster is running

Your cluster must already exist before you run this.

If you haven't deployed EKS yet:

```
GitHub → Actions → EKS Terraform → Run workflow → environment = production → action = apply
```

If your cluster is already running, skip to Step 2.

---

### Step 2: Push this code to GitHub

Make sure the `ses-terraform/` folder and `.github/workflows/ses-terraform.yml` are on the `main` branch.

If not pushed yet:

```bash
git add -A
git commit -m "Add SES Terraform module"
git push origin main
```

---

### Step 3: Run the SES workflow

1. Open your browser
2. Go to: `https://github.com/Arealis-network/Zord-Infrastructure-aws`
3. Click `Actions` tab
4. On the left sidebar, click `SES Terraform`
5. Click the blue button `Run workflow`
6. Set:
   - Environment: `production`
   - Action: `apply`
7. Click the green `Run workflow` button

Wait for it to finish (should take 1-2 minutes).

---

### Step 4: Get the DNS records

After the workflow finishes:

1. Click on the completed run
2. Scroll down to the bottom
3. You will see a **summary section** with all the DNS records you need

It will look something like this:

```
Domain: zordnet.com
Verification TXT: some-long-token-string
DKIM tokens: abc123, def456, ghi789
MAIL FROM: mail.zordnet.com
```

---

### Step 5: Add DNS records to your domain

Go to wherever you manage `zordnet.com` DNS (Cloudflare, GoDaddy, Namecheap, Route 53, etc.)

Add these records:

#### Record 1: Domain Verification

| Type | Host/Name | Value |
|---|---|---|
| TXT | `_amazonses.zordnet.com` | *(the verification token from Step 4)* |

#### Records 2, 3, 4: DKIM (you get 3 tokens)

For each DKIM token (let's call them `abc123`, `def456`, `ghi789`):

| Type | Host/Name | Value |
|---|---|---|
| CNAME | `abc123._domainkey.zordnet.com` | `abc123.dkim.amazonses.com` |
| CNAME | `def456._domainkey.zordnet.com` | `def456.dkim.amazonses.com` |
| CNAME | `ghi789._domainkey.zordnet.com` | `ghi789.dkim.amazonses.com` |

#### Record 5: MAIL FROM MX

| Type | Host/Name | Value | Priority |
|---|---|---|---|
| MX | `mail.zordnet.com` | `feedback-smtp.ap-south-1.amazonses.com` | 10 |

#### Record 6: MAIL FROM SPF

| Type | Host/Name | Value |
|---|---|---|
| TXT | `mail.zordnet.com` | `v=spf1 include:amazonses.com ~all` |

---

### Step 6: Wait for verification

After you add the DNS records:

1. Go to AWS Console
2. Go to: `SES → Verified identities`
3. Click on `zordnet.com`
4. Wait 5-10 minutes
5. Status will change from `Pending` to `Verified`

You don't need to do anything else. AWS checks DNS automatically.

---

### Step 7: Request SES production access (one-time)

New AWS accounts are in "sandbox mode" which means you can only send emails to verified email addresses.

To send emails to any address (your real users):

1. Go to AWS Console
2. Go to: `SES → Account dashboard`
3. Click `Request production access`
4. Fill in:
   - Mail type: `Transactional`
   - Website URL: your app URL
   - Use case: "We send OTP verification codes to users during login and registration"
5. Submit

AWS reviews this in 24 hours. They almost always approve transactional email requests.

---

### Step 8: Verify it works

SSH into your EC2 admin box and test:

```bash
aws ses send-email \
  --from "noreply@zordnet.com" \
  --destination "ToAddresses=your-email@gmail.com" \
  --message "Subject={Data=Test OTP},Body={Text={Data=Your code is 123456}}" \
  --region ap-south-1
```

If you're still in sandbox, the `--destination` email must be a verified email address. Add it in SES Console → Verified identities → Create identity → Email address.

---

### Step 9: Your app sends emails automatically

Your app pods running in:
- Namespace: `zord`
- Service account: `zord-app`

Already have SES permissions via Pod Identity. No API keys needed.

Your app code just uses the AWS SDK:

```go
// Go example — credentials are injected automatically by Pod Identity
cfg, _ := config.LoadDefaultConfig(ctx, config.WithRegion("ap-south-1"))
client := ses.NewFromConfig(cfg)

client.SendEmail(ctx, &ses.SendEmailInput{
    Source: aws.String("noreply@zordnet.com"),
    Destination: &types.Destination{
        ToAddresses: []string{"user@example.com"},
    },
    Message: &types.Message{
        Subject: &types.Content{Data: aws.String("Your Verification Code")},
        Body:    &types.Body{Text: &types.Content{Data: aws.String("Your OTP: 847291")}},
    },
})
```

---

## That's It!

The full flow is:

```
1. Push code to GitHub                    (1 minute)
2. Run SES Terraform apply                (1 minute)  
3. Add 6 DNS records                      (5 minutes)
4. Wait for SES verification              (5-10 minutes)
5. Request production access              (24 hours, one-time)
6. Your app can send OTP emails           ✓
```

---

## How To Destroy

If you ever want to remove SES:

1. GitHub → Actions → SES Terraform → Run workflow
2. Environment: `production`
3. Action: `destroy`
4. confirm_destroy: `yes`
5. Run

Then delete the DNS records from your domain provider.

---

## State Files

| Environment | State Key |
|---|---|
| staging | `ses/staging/terraform.tfstate` |
| production | `ses/production/terraform.tfstate` |

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `environment` | `production` | staging or production |
| `aws_region` | `ap-south-1` | AWS region |
| `ses_domain` | `zordnet.com` | Domain for SES |
| `eks_cluster_name` | *(auto from environment)* | Auto-derives: `arealis-zord-prod-eks` or `arealis-zord-stg-eks` |
| `workload_namespace` | `zord` | K8s namespace of your app pods |
| `workload_service_account` | `zord-app` | K8s service account of your app pods |

---

## Local Commands (Optional)

If you want to run Terraform from your machine instead of GitHub Actions:

```bash
cd ses-terraform

terraform init \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="key=ses/production/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"

terraform plan -var="environment=production"
terraform apply -var="environment=production"
```

---

## Troubleshooting

**"Email address is not verified"**
→ You're still in SES sandbox. Either verify the recipient email in SES Console, or request production access.

**"Domain not verified"**
→ DNS records not propagated yet. Wait 10 more minutes, or check if you added them correctly.

**"AccessDenied when sending from pod"**
→ Check that your pod uses service account `zord-app` in namespace `zord`. Run:
```bash
kubectl get pod <pod-name> -n zord -o jsonpath='{.spec.serviceAccountName}'
```

**"Pod identity not working"**
→ Make sure the `eks-pod-identity-agent` addon is running:
```bash
kubectl get pods -n kube-system | grep pod-identity
```
