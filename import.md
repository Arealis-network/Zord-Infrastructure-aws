# Important Notes

## Why we use a NAT Gateway

You're using a NAT Gateway because your EKS nodes live in **private subnets** — and
private subnets have no direct internet access. But the nodes still need outbound
internet to function.

### What needs outbound internet (goes through the NAT)
- Pulling container images (ECR, Docker Hub, public registries)
- Calling AWS APIs (EKS, Secrets Manager, S3, etc.)
- ArgoCD pulling from GitHub
- Karpenter, External-DNS, cert-manager reaching AWS/external endpoints
- OS/package updates

### Why private subnets + NAT instead of just putting nodes in public subnets
- **Security.** Private nodes have **no inbound** path from the internet — nothing
  can connect *to* them directly. The NAT only allows **outbound** (node → internet),
  never inbound (internet → node). That's the standard secure EKS pattern.
- Public-facing traffic comes in through **load balancers (ALB/NLB)** in the public
  subnets, which forward to the private nodes. So users reach your apps, but can't
  touch the nodes directly.

### The flow
```
Users → ALB (public subnet) → Pods (private subnet)              [inbound, controlled]
Nodes (private subnet) → NAT Gateway (public subnet) → Internet  [outbound only]
```

So the NAT Gateway is what lets your locked-down private nodes still pull images and
talk to AWS, without exposing them to the internet. It's the security best-practice
for production EKS — keep nodes private, allow only outbound through NAT, accept
inbound only through load balancers.

The tradeoff is cost (~$32/mo + data) — but that's the price of not exposing your
nodes publicly. Worth it for prod.
