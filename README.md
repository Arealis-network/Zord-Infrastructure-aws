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
- If `tool.sh` changes, Terraform replaces the EC2 instance and reruns bootstrap
