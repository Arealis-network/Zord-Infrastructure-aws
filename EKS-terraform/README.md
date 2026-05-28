# EKS Terraform Deployment Guide

This folder contains the Terraform code to create, update, and delete your Amazon EKS cluster for **staging** and **production** environments using the same code.

## Multi-Environment Support

When you run the workflow, you pick an environment:

| | Staging | Production |
|---|---|---|
| Cluster name | `arealis-zord-stg-eks` | `arealis-zord-prod-eks` |
| VPC CIDR | `10.1.0.0/16` | `10.0.0.0/16` |
| State key | `eks/staging/terraform.tfstate` | `eks/production/terraform.tfstate` |
| IAM prefix | `arealis-zord-stg-eks-*` | `arealis-zord-prod-eks-*` |
| Node group | `arealis-zord-stg-eks-node-group` | `arealis-zord-prod-eks-node-group` |
| Secrets access | `staging/zord/app-secrets` | `production/zord/app-secrets` |

Both environments are fully isolated. You can deploy, destroy, or update one without affecting the other.

## Workflow Trigger Rules

The GitHub Actions workflow file is:

```text
/.github/workflows/eks-terraform.yml
```

This workflow works like this:

1. **Pull request trigger** — If you create or update a PR with changes inside `EKS-terraform/`, the pipeline runs a plan automatically.

2. **Manual trigger** — Open GitHub Actions and run the workflow manually with your chosen environment and action.

Important:

- It does not auto-trigger on `main` or `master`
- It only auto-triggers on pull requests
- Manual run is required for apply or destroy

## Manual Workflow Options

When you run the workflow manually, you choose:

```
Environment: [staging | production]
Action:      [plan | apply | destroy]
```

If you select `destroy`, then you must set:

```text
confirm_destroy = yes
```

That will delete the entire Terraform-managed cluster for that environment.

## GitHub Repository Secrets

Open:

```text
GitHub Repository -> Settings -> Secrets and variables -> Actions
```

Add these repository secrets:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state |

These are shared across both environments.

## How To Create The S3 Bucket For Terraform State

Use a globally unique bucket name.

Example:

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
```

GitHub Actions runs Terraform with:

- S3 bucket from `TF_STATE_BUCKET`
- Region `ap-south-1`
- State key based on the selected environment
- Encryption enabled

## How To Run The Workflow Manually

Go to:

```text
GitHub Repository -> Actions -> EKS Terraform -> Run workflow
```

Then choose:

- Environment: `staging` or `production`
- Action: `plan`, `apply`, or `destroy`

If you choose `destroy`, set:

```text
confirm_destroy = yes
```

## How To Deploy A Cluster Through GitHub Actions

1. Push your code to GitHub
2. Open `Actions`
3. Select `EKS Terraform`
4. Click `Run workflow`
5. Choose your environment (e.g. `staging`)
6. Choose `apply`
7. Run the workflow

The workflow will:

- Check Terraform formatting
- Initialize the S3 backend with environment-specific state key
- Validate Terraform
- Apply the EKS Terraform code with `TF_VAR_environment` set
- Install Cluster Autoscaler
- Install External Secrets Operator

## How To Delete A Cluster Through GitHub Actions

1. Open `Actions`
2. Select `EKS Terraform`
3. Click `Run workflow`
4. Choose the environment to destroy (e.g. `staging`)
5. Choose `destroy`
6. Set `confirm_destroy` to `yes`
7. Run the workflow

Terraform will destroy all resources for that environment only. The other environment is untouched.

## How To Run Terraform Locally

Open terminal inside `EKS-terraform`.

### Staging

Init:

```bash
terraform init \
  -backend-config="bucket=my-eks-terraform-state-bucket" \
  -backend-config="key=eks/staging/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"
```

Plan:

```bash
terraform plan -var="environment=staging"
```

Apply:

```bash
terraform apply -var="environment=staging"
```

Destroy:

```bash
terraform destroy -var="environment=staging"
```

### Production

Init (use `-reconfigure` if switching from staging):

```bash
terraform init -reconfigure \
  -backend-config="bucket=my-eks-terraform-state-bucket" \
  -backend-config="key=eks/production/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="encrypt=true"
```

Plan:

```bash
terraform plan -var="environment=production"
```

Apply:

```bash
terraform apply -var="environment=production"
```

Destroy:

```bash
terraform destroy -var="environment=production"
```

## How To Connect To Your Cluster After Deployment

### Staging

```bash
aws eks update-kubeconfig --region ap-south-1 --name arealis-zord-stg-eks
```

### Production

```bash
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

Check services:

```bash
kubectl get svc -A
```

Check Helm releases:

```bash
helm list -A
```

## Useful AWS And Kubernetes Commands

Describe cluster (staging example):

```bash
aws eks describe-cluster --name arealis-zord-stg-eks --region ap-south-1
```

List node groups:

```bash
aws eks list-nodegroups --cluster-name arealis-zord-stg-eks --region ap-south-1
```

Check autoscaler pod:

```bash
kubectl get pods -n kube-system | grep autoscaler
```

Check EBS CSI driver:

```bash
kubectl get pods -n kube-system | grep ebs
```

Check cluster info:

```bash
kubectl cluster-info
```

Check External Secrets Operator:

```bash
kubectl get pods -n external-secrets
kubectl get crd | grep external-secrets
```

## What Gets Created Per Environment

Each environment deploy creates:

- 1 VPC with 2 public + 2 private subnets
- 1 Internet Gateway + 1 NAT Gateway + EIP
- Route tables and associations
- 1 Security group
- 1 EKS cluster
- 1 Managed node group (3× `t3.medium`, scales to 10)
- EKS addons: vpc-cni, coredns, kube-proxy, pod-identity, EBS CSI driver
- OIDC provider
- IAM roles: cluster, worker, EBS CSI, Cluster Autoscaler, External Secrets Operator
- Pod identity associations
- 1 EC2 admin instance with Jenkins + SonarQube
- Cluster Autoscaler (Helm)
- External Secrets Operator (Helm)

## EC2 Admin Instance

Each environment gets its own EC2 admin instance (`t2.xlarge`) in the public subnet.

Access Jenkins:

```text
http://<EC2-PUBLIC-IP>:7777
```

Access SonarQube:

```text
http://<EC2-PUBLIC-IP>:7771
```

Get the EC2 public IP:

```bash
terraform output ec2_public_ip
```

Jenkins initial admin password:

```bash
cat /home/ec2-user/jenkins-initial-admin-password
```

## Notes

- Same Terraform code deploys both staging and production
- Environments are isolated by resource names, VPC CIDRs, state files, and IAM roles
- Pull requests trigger plan automatically
- Push to `main` or `master` does not trigger the workflow
- Manual workflow run is required for actual deployment or deletion
- The S3 bucket must exist before running the workflow
- Your AWS credentials must have permissions for EKS, EC2, VPC, IAM, Auto Scaling, and S3
- External Secrets Operator is installed automatically after `apply`
- Cluster Autoscaler is installed automatically after `apply`
- If `tool.sh` changes, Terraform replaces the EC2 instance and reruns bootstrap
