# Zord Infrastructure AWS

This repository provisions the AWS infrastructure for the Arealis Zord platform across **staging** and **production** environments using the same Terraform code.

It also installs External Secrets Operator and Cluster Autoscaler automatically after a successful EKS apply.

## Multi-Environment Architecture

Both environments live in the same AWS account but are fully isolated:

| | Staging | Production |
|---|---|---|
| Cluster name | `arealis-zord-stg-eks` | `arealis-zord-prod-eks` |
| VPC CIDR | `10.1.0.0/16` | `10.0.0.0/16` |
| Secrets prefix | `staging/zord/...` | `production/zord/...` |
| EKS state key | `eks/staging/terraform.tfstate` | `eks/production/terraform.tfstate` |
| Secrets state key | `secret-manager/staging/terraform.tfstate` | `secret-manager/production/terraform.tfstate` |
| IAM prefix | `arealis-zord-stg-eks-*` | `arealis-zord-prod-eks-*` |

You choose the environment from the workflow dropdown. Same code, different state.

## Deployment Method

This project is managed through GitHub Actions workflows:

```text
/.github/workflows/eks-terraform.yml
/.github/workflows/secrets-manager-terraform.yml
```

## Recommended Run Order

### Deploy staging

1. `Secret Manager Terraform` → environment = `staging`, action = `apply`
2. `EKS Terraform` → environment = `staging`, action = `apply`
3. Deploy Kubernetes manifests from the app repo targeting the staging cluster

### Deploy production

1. `Secret Manager Terraform` → environment = `production`, action = `apply`
2. `EKS Terraform` → environment = `production`, action = `apply`
3. Deploy Kubernetes manifests from the app repo targeting the production cluster

### Destroy an environment

1. `EKS Terraform` → environment = `staging`, action = `destroy`, confirm_destroy = `yes`
2. `Secret Manager Terraform` → environment = `staging`, action = `destroy`, confirm_destroy = `yes`

Destroying one environment does not affect the other.

## Workflow Trigger Rules

Both workflows work like this:

1. **Pull request trigger** — If you create or update a PR with changes in the relevant folder, the pipeline runs a plan automatically.

2. **Manual trigger** — Open GitHub Actions and run the workflow manually with your chosen environment and action.

Important:

- It does not auto-trigger on `main` or `master`
- It only auto-triggers on pull requests
- Manual run is required for apply or destroy

## Manual Workflow Options

When you run either workflow manually, you choose:

```
Environment: [staging | production]
Action:      [plan | apply | destroy]
```

If you select `destroy`, you must also set:

```text
confirm_destroy = yes
```

## GitHub Repository Secrets

Open:

```text
GitHub Repository -> Settings -> Secrets and variables -> Actions
```

Add these repository secrets:

### Shared (both environments)

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |

### Staging secrets

| Secret | Description |
|---|---|
| `ZORD_APP_SECRETS_JSON_STAGING` | JSON string for `staging/zord/app-secrets` |
| `ZORD_EDGE_SIGNING_KEY_JSON_STAGING` | JSON string for `staging/zord/edge-signing-key` |

### Production secrets

| Secret | Description |
|---|---|
| `ZORD_APP_SECRETS_JSON_PRODUCTION` | JSON string for `production/zord/app-secrets` |
| `ZORD_EDGE_SIGNING_KEY_JSON_PRODUCTION` | JSON string for `production/zord/edge-signing-key` |

## Create S3 Bucket For Terraform State

Use a globally unique bucket name:

```bash
aws s3api create-bucket --bucket my-eks-terraform-state-bucket --region ap-south-1
```

Enable versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket my-eks-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

Enable default encryption:

```bash
aws s3api put-bucket-encryption \
  --bucket my-eks-terraform-state-bucket \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

Block public access:

```bash
aws s3api put-public-access-block \
  --bucket my-eks-terraform-state-bucket \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Then store the bucket name in GitHub as `TF_STATE_BUCKET`.

## How Terraform State Is Stored

Each environment has its own state file in the same S3 bucket:

```text
eks/staging/terraform.tfstate
eks/production/terraform.tfstate
secret-manager/staging/terraform.tfstate
secret-manager/production/terraform.tfstate
```

This means environments are fully independent. You can destroy staging without touching production.

## How To Deploy Through GitHub Actions

1. Push your code to GitHub
2. Open `Actions`
3. Select the workflow (`EKS Terraform` or `Secret Manager Terraform`)
4. Click `Run workflow`
5. Choose your environment and action
6. Run the workflow

The EKS workflow will:

- Check Terraform formatting
- Initialize the S3 backend with the environment-specific state key
- Validate Terraform
- Apply the EKS Terraform code
- Install Cluster Autoscaler
- Install External Secrets Operator

## How To Delete An Environment Through GitHub Actions

1. Open `Actions`
2. Select `EKS Terraform`
3. Click `Run workflow`
4. Choose the environment to destroy
5. Set action to `destroy`
6. Set `confirm_destroy` to `yes`
7. Run the workflow

Then do the same for `Secret Manager Terraform` if you want to remove the secrets too.

## Local Terraform Commands

If needed, you can run Terraform locally. Example for staging:

```bash
cd EKS-terraform

terraform init \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="key=eks/staging/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"

terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

For production:

```bash
terraform init -reconfigure \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="key=eks/production/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"

terraform plan -var="environment=production"
terraform apply -var="environment=production"
```

To destroy:

```bash
terraform destroy -var="environment=staging"
```

## Connect To Your Cluster

After deploy, update kubeconfig:

```bash
# Staging
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-stg-eks

# Production
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-prod-eks
```

Check nodes:

```bash
kubectl get nodes
```

Check all pods:

```bash
kubectl get pods -A
```

## Get EC2 Public IP

After apply, get the EC2 admin instance public IP:

```bash
terraform output ec2_public_ip
```

Or from AWS:

```bash
aws ec2 describe-instances --region ap-south-1 \
  --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name,Tags[?Key=='Name'].Value|[0]]" \
  --output table
```

## Access Jenkins

```text
http://<EC2-PUBLIC-IP>:7777
```

Jenkins runs in Docker with port mapping `7777 -> 8080`.

## Access SonarQube

```text
http://<EC2-PUBLIC-IP>:7771
```

SonarQube runs in Docker with port mapping `7771 -> 9000`.

## EC2 Auto-Stop Schedule

The admin EC2 instance automatically stops at night and starts in the morning to save cost:

| Action | Time (IST) | Days |
|---|---|---|
| Stop | 10:00 PM | Every day |
| Start | 9:00 AM | Monday to Friday |

Stays stopped all weekend (Friday 10 PM → Monday 9 AM).

When it starts, Jenkins and SonarQube come back automatically — no commands needed.

**Important:** The EC2 public IP may change after stop/start. To find the new IP:

```bash
aws ec2 describe-instances --region ap-south-1 --filters "Name=tag:Name,Values=*admin*" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text
```

Or check in AWS Console → EC2 → your instance → Public IPv4 address.

If you need Jenkins on a weekend, manually start the instance from AWS Console.

## What Works When EC2 Admin Is Stopped

The admin EC2 only runs Jenkins and SonarQube. Your application runs entirely on EKS and pulls Docker images from ECR — not from the EC2.

| Question | Answer |
|---|---|
| App keeps running? | ✅ Yes |
| Pods restart successfully? | ✅ Yes (images are in ECR) |
| HPA scales up new pods? | ✅ Yes |
| Grafana / Kibana / Jaeger accessible? | ✅ Yes (runs in EKS) |
| Users can use the website? | ✅ Yes |
| Can deploy NEW code? | ❌ No (need Jenkins to build + push) |
| Can access Jenkins? | ❌ No (stopped) |
| Can access SonarQube? | ❌ No (stopped) |

Your existing application runs 24/7 regardless of the EC2 instance state.

![SonarQube](EKS-terraform/images/sonaroube.png)

## Jenkins Initial Admin Password

On the EC2 instance:

```bash
cat /home/ec2-user/jenkins-initial-admin-password
```

Or directly from the container:

```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

## Useful Checks On EC2

```bash
sudo docker ps
sudo docker logs jenkins --tail 50
sudo docker logs sonarqube --tail 50
sudo cat /var/log/tool-bootstrap.log
```

## Repository Structure

```text
.
├── .github/workflows/
│   ├── eks-terraform.yml              # EKS cluster workflow
│   └── secrets-manager-terraform.yml  # Secrets Manager workflow
├── EKS-terraform/
│   ├── main.tf                        # VPC, EKS, IAM, addons, EC2
│   ├── variables.tf                   # Environment + cluster variables
│   ├── outputs.tf                     # Cluster, network, IAM outputs
│   ├── tool.sh                        # EC2 bootstrap (Jenkins, SonarQube)
│   ├── install-autoscaler.sh          # Helm install Cluster Autoscaler
│   ├── install-external-secrets.sh    # Helm install External Secrets Operator
│   └── uninstall-helm.sh             # Pre-destroy Helm cleanup
├── secret-manager/
│   ├── main.tf                        # AWS Secrets Manager resources
│   ├── variables.tf                   # Environment + secret variables
│   └── outputs.tf                     # Secret name and ARN outputs
└── README.md
```

## Notes

- Same code deploys both staging and production
- Environments are isolated by resource names, VPC CIDRs, state files, and IAM roles
- Pull requests trigger plan automatically
- Manual workflow run is required for apply or destroy
- The S3 bucket must exist before running any workflow
- Jenkins and SonarQube are started by `EKS-terraform/tool.sh`
- External Secrets Operator is installed by the EKS workflow after apply
- If `tool.sh` changes, Terraform ignores it (EC2 is protected from recreation)

---

## How Auto-Scaling Works

The infrastructure automatically scales up when users come and scales down when they leave. You don't touch anything.

### At Rest (no traffic):

```
Stateful Node (t3.xlarge, always on):
├── Postgres (1 pod)
├── Kafka (1 pod)
└── Redis (1 pod)

Spot Node 1 (t3.large):
├── Kong × 2 (always 2)
├── zord-edge × 2 (always 2)
├── zord-console × 1
├── zord-relay × 1
└── FluentBit + node-exporter

Spot Node 2 (t3.large):
├── zord-intent-engine × 1
├── zord-outcome-engine × 1
├── zord-evidence × 1
├── zord-intelligence × 1
├── zord-prompt-layer × 1
├── zord-token-enclave × 1
├── ML service × 1
└── FluentBit + node-exporter

Admin EC2 (t3.large, separate):
├── Jenkins
└── SonarQube

Total: 3 EKS nodes + 1 admin = ~$18/day
```

### During Traffic Spike:

```
Users → ALB → Kong → zord-edge (CPU goes above 70%)
                          ↓
                    HPA scales pods: 2 → 3 → 4
                          ↓
                    Pods need space
                          ↓
                    Autoscaler adds Spot Node 3 (1-2 min)
                          ↓
                    Pods schedule, users get fast response
```

### When Traffic Drops:

```
HPA sees low CPU for 5 minutes
          ↓
Scales down: zord-edge 4 → 3 → 2
          ↓
Spot Node 3 becomes empty
          ↓
Autoscaler removes it after 2 minutes
          ↓
Back to 2 spot nodes, cost drops
```

### The Chain:

```
User traffic → Pod CPU ↑ → HPA scales pods ↑ → Autoscaler adds nodes ↑ → Bill goes up
No traffic   → Pod CPU ↓ → HPA removes pods ↓ → Autoscaler removes nodes ↓ → Bill goes down
```

---

## Cost Optimization

| Strategy | Implementation |
|---|---|
| Spot instances for stateless workloads | 60-70% cheaper than on-demand |
| HPA min=1 for non-critical services | Only run what's needed |
| HPA min=2 only for Kong + zord-edge | Entry points need instant availability |
| Cluster Autoscaler | Adds/removes nodes based on demand |
| Stateful node (on-demand) | Databases stay stable, never interrupted |
| EC2 lifecycle protection | Admin instance never destroyed on apply |

### Expected Cost:

| Period | Idle | Under Load |
|---|---|---|
| Daily | ~$18 | ~$25-35 |
| Monthly | ~$540 | ~$750-1000 |

The system auto-adjusts. You pay for what you use.
