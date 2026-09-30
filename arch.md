# Zord Public Request Flow

## Public URLs

| Environment | Website | API / Postman | Kong Manager | Internal origin |
|---|---|---|---|---|
| Staging ✅ | `stg-www.zordnet.com` | `stg-api.zordnet.com` | `stg-kong-admin.zordnet.com` | `stg-origin-api.zordnet.com` |
| Dev | `dev-www.zordnet.com` | `dev-api.zordnet.com` | `dev-kong-admin.zordnet.com` | `dev-origin-api.zordnet.com` |
| Production | `www.zordnet.com` | `api.zordnet.com` | `kong-admin.zordnet.com` | `origin-api.zordnet.com` |

## Public Request Flow

```text
┌─────────────────────────────────────┐
│ Users / Browser / Postman / Dev Team │
└─────────────────┬───────────────────┘
                  │ HTTPS
                  v
┌─────────────────────────────────────┐
│ Public URL                          │
│ www / api / kong-admin              │
└─────────────────┬───────────────────┘
                  │ Route 53 A + AAAA alias
                  v
┌─────────────────────────────────────┐
│ Amazon CloudFront                   │
│ TLS termination • API forwarding    │
└─────────────────┬───────────────────┘
                  │
                  v
┌─────────────────────────────────────┐
│ AWS WAF                             │
│ SQLi • bad input • rate limit        │
└─────────────────┬───────────────────┘
                  │ Adds X-Origin-Verify
                  │ Keeps original Host
                  v
┌─────────────────────────────────────┐
│ Internal Origin DNS                 │
│ *-origin-api.zordnet.com            │
│ External DNS → ALB                  │
└─────────────────┬───────────────────┘
                  │ HTTPS
                  v
┌─────────────────────────────────────┐
│ Shared Application Load Balancer     │
└─────────────────┬───────────────────┘
                  │
                  v
┌─────────────────────────────────────┐
│ Kong Gateway on Amazon EKS           │
│ Verify X-Origin-Verify               │
│ Route by Host                        │
└───────┬─────────────────┬───────────┘
        │                 │
        │                 │
        v                 v
┌───────────────┐   ┌─────────────────┐
│ www           │   │ api             │
│ Web App       │   │ API / Postman   │
└───────────────┘   └────────┬────────┘
                              │
                              v
                    ┌─────────────────┐
                    │ Zord Services   │
                    │ on Amazon EKS   │
                    └─────────────────┘

kong-admin → Kong Manager UI → basic authentication
Direct ALB request → no X-Origin-Verify → 403 Forbidden
```

**DNS ownership:** Terraform creates public `www` / `api` / `kong-admin` aliases
pointing to CloudFront. External DNS creates only `*-origin-api` pointing to ALB.

## Gemini / GPT MNC Architecture Prompt

```text
Create ONE board-ready MNC architecture diagram titled:
"Arealis Zord — Public Request Flow".

Use the supplied official Arealis Zord logo at the top-left. If no logo image is
attached, write the text "AREALIS ZORD" only; do not invent a logo.

Use official AWS icons for: Route 53, CloudFront, AWS WAF, Application Load
Balancer, Amazon EKS, AWS Secrets Manager, ACM. Use official Kubernetes and Kong
Gateway icons. Use connected boxes with clear arrows, white background, AWS blue
boundaries, minimal readable labels, and professional CTO/security-review style.

Show this exact public request flow from left to right:

Users / Browser / Postman / Dev Team
→ Route 53 public DNS
→ Amazon CloudFront
→ AWS WAF
→ Internal origin DNS (*-origin-api.zordnet.com)
→ Shared Application Load Balancer
→ Kong Gateway on Amazon EKS
→ Zord services on Amazon EKS.

Show the three public host types:
- www = website/browser client
- api = Postman, API, service-to-service
- kong-admin = Kong Manager UI behind basic authentication

Show public hostname examples in a small table:
- Staging: stg-www, stg-api, stg-kong-admin
- Dev: dev-www, dev-api, dev-kong-admin
- Production: www, api, kong-admin
All are under zordnet.com.

Show the security control:
CloudFront adds X-Origin-Verify. Kong verifies it. A dashed red attacker arrow
from the internet directly to the ALB ends in "403 Forbidden" because the request
has no X-Origin-Verify header.

Show DNS ownership as a small note:
Terraform owns public www/api/kong-admin → CloudFront.
External DNS owns only *-origin-api → ALB.

Do not include CI/CD, Jenkins, GitHub, ArgoCD, databases, observability, branches,
or deployment flow. Show only the public request path.
```
