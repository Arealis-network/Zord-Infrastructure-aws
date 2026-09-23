# Zord Edge Architecture (CloudFront → ALB → Kong)

This document describes how public traffic reaches the Arealis Zord platform, the
exact hostnames per environment, and who owns each piece. It is the single source
of truth for the edge/ingress path.

---

## 1. The rule

**Every public request goes through CloudFront + WAF. Nothing reaches the ALB
directly from the internet.** Direct hits to the ALB are rejected (HTTP 403) by
Kong's origin-verification check, because only CloudFront injects the required
`X-Origin-Verify` header.

There are **three public hostnames per environment**:

| Purpose | Who uses it |
|---|---|
| `api` | server API — Postman, service-to-service, backend calls |
| `www` | client — browser, web app |
| `kong-admin` | Kong Manager UI (basic-auth login: `admin` + `KONG_MANAGER_PASSWORD`) |

All are served by **one** CloudFront distribution per environment. `kong-admin`
goes through the same edge as customer traffic so it is protected by WAF and
origin-cloaking rather than sitting exposed on the ALB. See the hardening note in
section 5.

---

## 2. Hostnames per environment

| Environment | Client (`www`) | API (`api`) | Kong Manager (`kong-admin`) | All resolve to |
|---|---|---|---|---|
| production | `www.zordnet.com` | `api.zordnet.com` | `kong-admin.zordnet.com` | CloudFront |
| staging | `stg-www.zordnet.com` | `stg-api.zordnet.com` | `stg-kong-admin.zordnet.com` | CloudFront |
| dev | `dev-www.zordnet.com` | `dev-api.zordnet.com` | `dev-kong-admin.zordnet.com` | CloudFront |

Production has no prefix; staging is `stg-`, dev is `dev-`. All are single labels
under `zordnet.com`, so the one apex wildcard cert (`*.zordnet.com`) covers them.

---

## 3. Request flow

```
                        ┌──────────────────────────────┐
   Browser  ──────────► │  www.zordnet.com  (client)   │
   Postman  ──────────► │  api.zordnet.com  (server)   │   Route53 alias
                        └───────────────┬──────────────┘   (A + AAAA) → CloudFront
                                        │
                                        ▼
                        ┌──────────────────────────────┐
                        │        CloudFront + WAF        │  DDoS, WAF rules,
                        │  (one distribution per env)    │  rate limit, TLS
                        └───────────────┬──────────────┘
                                        │  injects header:
                                        │  X-Origin-Verify: <secret>
                                        │  forwards Host: api / www / kong-admin
                                        ▼
                        ┌──────────────────────────────┐
                        │   origin-api.zordnet.com       │  CloudFront origin =
                        │   (Route53 record published    │  a STABLE hostname,
                        │    AUTOMATICALLY by External    │  auto-published by
                        │    DNS -> the shared ALB)       │  External DNS -> ALB
                        └───────────────┬──────────────┘
                                        │
                                        ▼
                        ┌──────────────────────────────┐
                        │            Kong                │  1. verify X-Origin-Verify
                        │  (api-gateway namespace)       │     (else 403)
                        │                                │  2. route on Host:
                        │                                │     api → API services
                        │                                │     www → client app
                        │                                │     kong-admin → Manager UI
                        └───────────────┬──────────────┘
                                        │
                                        ▼
                        ┌──────────────────────────────┐
                        │   Zord microservices (zord ns) │
                        └──────────────────────────────┘
```

Key points:
- CloudFront forwards the original `Host` header, so Kong routes on `api`/`www`/`kong-admin`.
- CloudFront's origin is a **stable hostname** (`origin-api` per env), NOT one of
  the public names — that avoids the alias==origin loop.
- The app team's **External DNS** publishes `origin-api` → the ALB automatically
  from the Kong ingress. Nobody copies an ALB DNS name by hand.
- CloudFront is created **up front**, even before the ALB exists. Its origin is
  just a name that does not resolve yet; once Kong deploys and External DNS
  publishes `origin-api`, the origin resolves and traffic flows. Fully automatic
  and correctly ordered — no manual step, no ordering trap.

---

## 4. Why direct ALB access fails (by design)

```
   Attacker ──► k8s-...elb.amazonaws.com   (raw ALB DNS, guessed/scanned)
                        │
                        ▼  request has NO X-Origin-Verify header
                     Kong  ──►  403 Forbidden
```

Origin cloaking: CloudFront adds `X-Origin-Verify: <secret>` to every origin
request. Kong rejects anything without the correct value. So even if someone finds
the ALB DNS name, they cannot bypass CloudFront/WAF. The secret lives in AWS
Secrets Manager (`<env>/zord/cloudfront-origin-verify`) and is delivered to Kong
via External Secrets Operator. This is why a browser hitting the ALB or the raw
name directly correctly returns `{"message":"Forbidden"}` — including for
`kong-admin` until it is reached through CloudFront.

### Hardening note: the Kong Manager UI (`kong-admin`)

`kong-admin` is an administrative surface. It currently rides the same CloudFront
distribution as customer traffic, so it is protected by WAF, origin-cloaking, and
Kong basic-auth (`admin` + `KONG_MANAGER_PASSWORD` from Secrets Manager). For a
stricter posture, restrict it further with one of:
- a CloudFront/WAF IP allow-list (office/VPN CIDRs) scoped to the `kong-admin` host, or
- moving it off the public edge entirely and reaching it via `kubectl port-forward`
  or a private/VPN path.
The Kong **Admin API** (config plane) is NOT public — only the Manager UI is, and
only behind basic-auth.

---

## 5. Ownership

| Layer | Owner | Where |
|---|---|---|
| Route53 alias `api`/`www`/`kong-admin` → CloudFront | **Infra** | `live/components/06-edge` (this repo) |
| CloudFront distribution + WAF | **Infra** | `modules/aws-cloudfront-waf` |
| Origin-verify secret (Secrets Manager) | **Infra** | `modules/aws-cloudfront-waf` |
| Route53 record `origin-api` → ALB (auto) | **K8s / app** | External DNS, from the Kong ingress |
| Shared ALB (created by AWS LB Controller) | **K8s / app** | app repo Kong ingress |
| Kong routes + origin-verify check | **Kong / app** | app repo `kong.yaml` |
| Microservices | **App** | app repo charts |

CloudFront's origin is a **stable hostname** (`origin-api` per env), NOT a public
name and NOT the raw ALB DNS. Infra sets it from `edge.origin_subdomain`; the app
team's External DNS auto-publishes it to the ALB. Nobody copies an ALB DNS name by
hand, and CloudFront can be created before the ALB exists.

---

## 6. Bring-up order (per environment) — fully automatic

```
1. Infra: apply any time (even before Kong exists).
     → CloudFront + WAF created, origin = origin-api.<apex> (not resolving yet).
     → Public api/www/kong-admin Route53 aliases -> CloudFront.
2. App team: deploy Kong. AWS LB Controller creates the ALB, and External DNS
   AUTOMATICALLY publishes origin-api.<apex> -> the ALB (one ingress annotation).
3. That's it. CloudFront's origin now resolves -> traffic flows. No manual step.
4. Test:
     api  (Postman)  https://stg-api.zordnet.com/...        → 200 via CloudFront
     www  (browser)  https://stg-www.zordnet.com/           → 200 via CloudFront
     kong-admin      https://stg-kong-admin.zordnet.com/    → Manager UI (basic-auth)
     raw ALB DNS directly                                   → 403 (cloaking works)
```

Between steps 1 and 2 the public URLs return 5xx (origin not resolving yet). This
is a harmless "not ready" state that self-heals the instant Kong is up — no error,
no re-apply needed.

### What the app team must set on the Kong ingress (one time)

External DNS must publish the ORIGIN name, not the public names:

```yaml
metadata:
  annotations:
    # Publish ONLY the origin name -> the ALB. Do NOT publish api/www/kong-admin;
    # those are infra-owned Route53 aliases to CloudFront.
    external-dns.alpha.kubernetes.io/hostname: stg-origin-api.zordnet.com
```

Kong still needs ROUTES for the public hosts (api/www/kong-admin) because
CloudFront forwards the public Host header — only the DNS publication changes.

---

## 7. Configuration reference

Per environment, in `live/environments/<env>/config.json`:

```json
"edge": {
  "enabled": true,
  "subdomain": "api",                               // primary (used for public_url)
  "public_subdomains": ["api", "www", "kong-admin"],// public hosts -> CloudFront
  "origin_subdomain": "origin-api",                 // stable origin -> ALB (External DNS)
  "waf_rate_limit": 2000,
  "kong_alb_domain_name": ""                        // optional: force a raw ALB DNS origin
}
```

Terraform outputs from `06-edge`:

- `public_url` — primary API URL (e.g. `https://stg-api.zordnet.com`)
- `public_fqdns` — all public hosts (`api`, `www`, `kong-admin`)
- `cloudfront_domain_name` — the CloudFront distribution domain
- `origin_fqdn` — the stable origin hostname the app team's External DNS must publish → ALB

---

## 8. Prompt for generating an architecture diagram (Gemini / GPT)

Paste the block below into Gemini or GPT to generate a clean end-to-end diagram.
It is self-contained — everything the model needs is in the prompt.

```text
Create a clear, professional end-to-end AWS architecture diagram for a
multi-environment fintech platform called "Zord". Use a top-to-bottom flow with
labeled boxes and arrows. Keep it clean and MNC-grade (production quality).

CORE RULE TO SHOW VISUALLY:
All public traffic MUST enter through Amazon CloudFront + AWS WAF. Nothing reaches
the load balancer directly from the internet. Show a rejected/blocked path for any
direct-to-ALB attempt.

ENVIRONMENTS (show as three parallel columns or a note; identical shape, different
hostnames):
- production: www.zordnet.com, api.zordnet.com, kong-admin.zordnet.com
- staging:    stg-www.zordnet.com, stg-api.zordnet.com, stg-kong-admin.zordnet.com
- dev:        dev-www.zordnet.com, dev-api.zordnet.com, dev-kong-admin.zordnet.com

THREE PUBLIC ENTRYPOINTS PER ENVIRONMENT (all go to the SAME CloudFront distribution):
1. "www" = client/browser traffic (the web app)
2. "api" = server API traffic (Postman, backend, service-to-service)
3. "kong-admin" = Kong Manager admin UI, behind basic-auth (show as a smaller/side box)

FLOW (top to bottom):
1. Users: a Browser (using www) and Postman/Backend (using api).
2. Amazon Route 53: A + AAAA alias records for both www and api point to CloudFront.
3. Amazon CloudFront + AWS WAF: one distribution serves both www and api as aliases.
   It provides TLS termination, WAF rules, rate limiting, and DDoS protection.
   It injects a secret HTTP header "X-Origin-Verify: <secret>" on every request it
   forwards to the origin, and forwards the original Host header (www/api).
4. Origin: a shared internet-facing Application Load Balancer (ALB), addressed by
   its raw AWS DNS name (not a public vanity domain).
5. Kong API Gateway (running in Kubernetes, namespace api-gateway):
   - First checks the X-Origin-Verify header. If missing/wrong -> 403 Forbidden.
   - Then routes by Host: "api" hostnames -> backend API services; "www" hostnames
     -> the client web app.
6. Zord microservices running in Amazon EKS (namespace zord).

ALSO SHOW:
- A dashed "BLOCKED" arrow from an attacker hitting the ALB's raw DNS name directly,
  ending at Kong returning "403 Forbidden" — because there is no X-Origin-Verify
  header. Label it "origin cloaking".
- AWS Secrets Manager holding the X-Origin-Verify secret, delivered into Kong via
  the External Secrets Operator (ESO). Draw this as a side feed into Kong.
- A note that one ACM wildcard certificate (*.zordnet.com) secures all hostnames.

STYLE:
- Use official AWS service icons where possible (Route 53, CloudFront, WAF, ALB,
  EKS, Secrets Manager) plus a Kubernetes/Kong icon for the gateway.
- Left-to-right or top-to-bottom, clean labels, minimal clutter.
- Title: "Zord Platform — Public Edge Architecture (CloudFront → ALB → Kong)".
```
