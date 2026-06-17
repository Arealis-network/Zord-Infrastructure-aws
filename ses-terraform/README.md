# AWS SES Email Setup — OTP Verification

This guide sets up AWS SES so your app can send OTP emails to users.

SES code is now part of `EKS-terraform/main.tf`. This README is just the setup guide.

---

## How It Works

```
User enters email on your website
        ↓
Your app generates OTP (e.g., 847291)
        ↓
Your app stores OTP in Redis (5 min expiry)
        ↓
Your app calls AWS SES:
    FROM: no-reply@zordnet.com
    TO: user@gmail.com
    Body: "Your OTP is 847291"
        ↓
User gets email, types OTP on website
        ↓
Your app checks Redis → Login success
```

Your pods get SES permission automatically via EKS Pod Identity. No API keys in code.

---

## Current Status

| Item | Status |
|---|---|
| Domain `zordnet.com` | ✅ Verified |
| Email `no-reply@zordnet.com` | ✅ Verified |
| Email `support@zordnet.com` | ✅ Verified |
| IAM role for pods | ✅ Created by EKS Terraform |
| Pod Identity association | ✅ Linked to `zord-app` service account |
| SES production access | ⚠️ You must request this (see below) |

---

## Step 1: Request SES Production Access

This is REQUIRED. Without this, your app can only send emails to verified addresses (not real users).

1. Open your browser
2. Go to: **AWS Console → SES**
3. Left sidebar → click **Account dashboard**
4. Click the blue button **"Request production access"**
5. Fill in:

| Field | Value |
|---|---|
| Mail type | **Transactional** |
| Website URL | `https://zordnet.com` |
| Use case description | Copy-paste the text below |

**Use case text (copy this exactly):**

```
We send one-time password (OTP) verification codes to users during login and registration on our platform zordnet.com. Emails are sent from no-reply@zordnet.com. We expect low volume initially (under 1000 emails/day). Users explicitly request these emails by clicking "send code" on our login page. We do not send marketing or bulk emails.
```

6. Click **Submit**

AWS reviews this in **24 hours**. They almost always approve transactional email requests.

After approval: your app can send to ANY email in the world.

---

## Step 2: Add DNS Records (If Not Done Yet)

If you haven't added DNS records yet, get them from:

**AWS Console → SES → Identities → zordnet.com → Authentication tab**

Add these to your DNS provider:

### Domain Verification (TXT)

| Type | Host | Value |
|---|---|---|
| TXT | `_amazonses.zordnet.com` | *(copy from SES Console)* |

### DKIM (3 CNAME records)

| Type | Host | Value |
|---|---|---|
| CNAME | `<token1>._domainkey.zordnet.com` | `<token1>.dkim.amazonses.com` |
| CNAME | `<token2>._domainkey.zordnet.com` | `<token2>.dkim.amazonses.com` |
| CNAME | `<token3>._domainkey.zordnet.com` | `<token3>.dkim.amazonses.com` |

### MAIL FROM (MX + SPF)

| Type | Host | Value |
|---|---|---|
| MX | `mail.zordnet.com` | `10 feedback-smtp.ap-south-1.amazonses.com` |
| TXT | `mail.zordnet.com` | `v=spf1 include:amazonses.com ~all` |

If all identities show "Verified" in SES Console, DNS is already done. Skip this step.

---

## Step 3: Give Developers Local Access

For developers to test OTP emails locally, they need an IAM user with SES permissions.

### Create IAM User (one-time)

1. AWS Console → IAM → Users → Create user
2. Name: `zord-dev-ses`
3. Attach this inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    }
  ]
}
```

4. Create access key → "Application running outside AWS"
5. Share credentials with developers

### Developer `.env` File

Developers add this to their local `.env`:

```env
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=ap-south-1
SES_FROM_EMAIL=no-reply@zordnet.com
```

---

## Step 4: Handle Sandbox Limitation (Until Production Access Approved)

While waiting for production access (24 hours), developers can only send TO verified emails.

To verify a developer's email:

1. AWS Console → SES → Verified identities → Create identity
2. Choose: **Email address**
3. Enter: `developer@gmail.com`
4. Developer clicks verification link in their inbox
5. Done — SES can now send TO that email

After production access is approved, this step is no longer needed.

---

## Step 5: Test It

### From EC2 (quick test)

```bash
aws ses send-email \
  --from "no-reply@zordnet.com" \
  --destination "ToAddresses=your-verified-email@gmail.com" \
  --message "Subject={Data=Test OTP},Body={Text={Data=Your code is 123456}}" \
  --region ap-south-1
```

### From Developer's Machine

```bash
AWS_ACCESS_KEY_ID=AKIA... \
AWS_SECRET_ACCESS_KEY=... \
AWS_REGION=ap-south-1 \
aws ses send-email \
  --from "no-reply@zordnet.com" \
  --destination "ToAddresses=your-verified-email@gmail.com" \
  --message "Subject={Data=Test OTP},Body={Text={Data=Your code is 847291}}" \
  --region ap-south-1
```

Check inbox. If you get the email, everything works.

---

## How It Works In Production (Inside EKS)

Your app pods in EKS don't need any `.env` file or API keys.

```
Pod (namespace: zord, service account: zord-app)
        ↓
EKS Pod Identity automatically injects AWS credentials
        ↓
App uses AWS SDK → ses.SendEmail()
        ↓
AWS SES delivers email to the user
```

No secrets. No environment variables for AWS. Pod Identity handles it.

### Example Go Code

```go
cfg, _ := config.LoadDefaultConfig(ctx, config.WithRegion("ap-south-1"))
client := ses.NewFromConfig(cfg)

client.SendEmail(ctx, &ses.SendEmailInput{
    Source: aws.String("no-reply@zordnet.com"),
    Destination: &types.Destination{
        ToAddresses: []string{"user@gmail.com"},
    },
    Message: &types.Message{
        Subject: &types.Content{Data: aws.String("Your Verification Code")},
        Body:    &types.Body{Text: &types.Content{Data: aws.String("Your OTP: 847291")}},
    },
})
```

---

## Summary — What You Need To Do

| # | Action | Time | One-time? |
|---|---|---|---|
| 1 | Request SES production access | 5 min (24h review) | Yes |
| 2 | Add DNS records (if not done) | 5 min | Yes |
| 3 | Create IAM user for developers | 5 min | Yes |
| 4 | Verify developer emails (sandbox only) | 2 min each | Until production approved |
| 5 | Test with `aws ses send-email` | 1 min | - |

After production access is approved and DNS is verified, your app can send OTP emails to anyone in the world.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Email address is not verified" | You're in sandbox. Verify the recipient email, or wait for production access |
| "MessageRejected: Email address not verified" | Same as above — sandbox restriction |
| "AccessDenied" from EC2 | Your EC2 has AdministratorAccess, should work. Check region matches |
| "AccessDenied" from pod | Check service account is `zord-app` in namespace `zord` |
| Email goes to spam | Add DKIM + SPF DNS records. Check "Authentication" tab in SES shows all green |
| "Sending paused" | You hit the sandbox limit (200 emails/day). Request production access |

---

## Available Sender Addresses

You can send from any of these:

- `no-reply@zordnet.com` — for OTP codes (users shouldn't reply)
- `support@zordnet.com` — for support emails (users can reply)
- `anything@zordnet.com` — domain is verified, any address works

---

## Where The Code Lives

SES Terraform resources are inside `EKS-terraform/main.tf` at the bottom (section: `SES EMAIL (OTP MFA)`).

Variables in `EKS-terraform/variables.tf`:

| Variable | Default |
|---|---|
| `ses_domain` | `zordnet.com` |
| `ses_workload_namespace` | `zord` |
| `ses_workload_service_account` | `zord-app` |

Deploys automatically with `EKS Terraform → apply`. No separate workflow needed.
