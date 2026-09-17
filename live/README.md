# Live Infrastructure — environment × component layout

This is the deployment surface. Each directory below is an independent Terraform
root module with **its own state file**, so a change to one component can never
accidentally modify another.

```
live/
  <environment>/            dev | staging | production
    01-foundation/          VPC, subnets, NAT, flow logs, KMS keys
    02-data/                RDS Postgres, S3 buckets
    03-compute/             EKS cluster, node groups, EKS addons, bastion
    04-security/            IAM/Pod Identity, Secrets Manager, SES
    05-platform/            Helm: ESO, LB controller, autoscaler, metrics,
                            EBS CSI, External DNS, Argo Rollouts, ArgoCD
    06-edge/                CloudFront + WAF
```

## Why numbered

The prefix encodes apply order. Later components read earlier ones through
`terraform_remote_state`, so they must be applied in sequence:

```
01-foundation → 02-data → 03-compute → 04-security → 05-platform → 06-edge
```

`terraform destroy` runs in reverse (06 → 01).

## Why split at all

One state per component means:

- A platform change cannot plan a VPC replacement.
- Blast radius is one component, not the whole environment.
- `05-platform` (Helm, changes often) is decoupled from `01-foundation`
  (network, changes almost never).
- The Kubernetes/Helm providers live only in `05-platform`, where the cluster
  already exists — they are not evaluated during a network or data apply.

## Usage

Every component is driven by the same two files from its environment:

```bash
cd live/staging/01-foundation
terraform init -reconfigure -backend-config=../backend.hcl -backend-config="key=eks/staging/01-foundation.tfstate"
terraform apply -var-file=../terraform.tfvars
```

The pipeline does this automatically for every component in order — see
`.github/workflows/infrastructure.yml`.

## Shared, reusable modules

All components consume the versioned modules in `../../../modules/`. Those
modules contain no environment-specific values; every difference between
environments lives in `live/<env>/terraform.tfvars`.
