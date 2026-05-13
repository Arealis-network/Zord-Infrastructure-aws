# Secret Manager Terraform Guide

This folder is for AWS Secrets Manager.

This Terraform code does **not** create your EKS cluster.

This folder only creates these 2 AWS Secrets Manager secret containers:

- `zord/app-secrets`
- `zord/edge-signing-key`

Then GitHub Actions will put the real secret values inside them.

That means this flow is:

1. Terraform creates the secret names in AWS
2. GitHub Actions reads your GitHub secrets
3. GitHub Actions writes the real JSON values into AWS Secrets Manager

This is good because your real secrets do not get stored in Terraform state.

## Where This Fits In The Full Flow

This folder is only the first part.

Your full deployment flow is:

1. run `secret-manager` workflow with `apply`
2. run `EKS Terraform` workflow with `apply`
3. EKS workflow installs External Secrets Operator automatically
4. deploy the Kubernetes manifests from your app repo
5. External Secrets Operator reads AWS Secrets Manager and creates Kubernetes secrets inside the cluster

So this folder creates the AWS side.

The EKS workflow creates the cluster side.

Your app repo uses these Kubernetes resources:

- `SecretStore`
- `ExternalSecret`

Those resources tell the operator which AWS secrets to read.

## What This Folder Has

Files in this folder:

- `secret-manager/main.tf`
- `secret-manager/variables.tf`
- `secret-manager/outputs.tf`

Workflow file:

- `.github/workflows/secrets-manager-terraform.yml`

## What You Must Do First

Before running the workflow, you must add GitHub repository secrets.

Open:

`GitHub repo -> Settings -> Secrets and variables -> Actions`

You need these GitHub secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TF_STATE_BUCKET`
- `ZORD_APP_SECRETS_JSON`
- `ZORD_EDGE_SIGNING_KEY_JSON`

## What Each GitHub Secret Means

### `AWS_ACCESS_KEY_ID`

Your AWS access key ID.

### `AWS_SECRET_ACCESS_KEY`

Your AWS secret access key.

### `TF_STATE_BUCKET`

The S3 bucket name where Terraform remote state is stored.

This stack uses this Terraform state key:

`secret-manager/terraform.tfstate`

### `ZORD_APP_SECRETS_JSON`

This is one full JSON string.

It will become the value of AWS secret:

`zord/app-secrets`

### `ZORD_EDGE_SIGNING_KEY_JSON`

This is one full JSON string.

It will become the value of AWS secret:

`zord/edge-signing-key`

## Step By Step: Add `ZORD_APP_SECRETS_JSON`

Open GitHub:

`Settings -> Secrets and variables -> Actions`

Click:

`New repository secret`

Secret name:

```text
ZORD_APP_SECRETS_JSON
```

Paste one full JSON value like this:

```json
{
  "POSTGRES_SUPERUSER_PASSWORD": "your-real-postgres-admin-password",
  "EDGE_DB_PASSWORD": "zord_password",
  "INTENT_DB_PASSWORD": "intent_password",
  "RELAY_DB_PASSWORD": "relay_password",
  "TOKEN_DB_PASSWORD": "token_password",
  "OUTCOME_DB_PASSWORD": "outcome_password",
  "EVIDENCE_DB_PASSWORD": "evidence_password",
  "INTELLIGENCE_DB_PASSWORD": "zpi_secret",
  "ZORD_VAULT_KEY": "your-real-vault-key",
  "INTERNAL_ADMIN_KEY": "your-real-admin-key",
  "MASTER_KEY": "W2MSQaooUlXVmVxGB7NgU06keCyKgQ+NlbdaDHCERAE=",
  "TOKEN_SECRET": "your-real-base64-token-secret",
  "EVIDENCE_SIGNING_PRIVATE_KEY_BASE64": "your-real-base64-evidence-private-key",
  "EVIDENCE_ARCHIVE_ENCRYPTION_KEY_BASE64": "your-real-base64-archive-key",
  "GEMINI_API_KEYS": "your-gemini-key-1,your-gemini-key-2",
  "EDGE_S3_BUCKET": "your-edge-bucket-name",
  "INTENT_S3_BUCKET": "your-intent-bucket-name",
  "OUTCOME_S3_BUCKET": "your-outcome-bucket-name",
  "EVIDENCE_S3_BUCKET": "your-evidence-bucket-name",
  "RELAY_SERVICES_0_AUTH_TOKEN": "dev-dummy-token-123",
  "RELAY_SERVICES_1_AUTH_TOKEN": "dev-dummy-token-123",
  "RELAY_SERVICES_2_AUTH_TOKEN": "dev-dummy-token-123",
  "RELAY_DB_URL": "postgres://relay_user:relay_password@zord-postgres:5432/zord_relay_db?sslmode=disable",
  "INTELLIGENCE_DATABASE_URL": "postgres://zpi:zpi_secret@zord-postgres:5432/zord_intelligence?sslmode=disable",
  "EDGE_READ_DSN": "postgres://zord_user:zord_password@zord-postgres:5432/zord_edge_db?sslmode=disable",
  "INTENT_READ_DSN": "postgres://intent_user:intent_password@zord-postgres:5432/zord_intent_engine_db?sslmode=disable",
  "RELAY_READ_DSN": "postgres://relay_user:relay_password@zord-postgres:5432/zord_relay_db?sslmode=disable",
  "INTELLIGENCE_READ_DSN": "postgres://zpi:zpi_secret@zord-postgres:5432/zord_intelligence?sslmode=disable",
  "EVIDENCE_READ_DSN": "postgres://evidence_user:evidence_password@zord-postgres:5432/zord_evidence_db?sslmode=disable"
}
```

Then click:

`Add secret`

## S3 Bucket Keys

The app deployment manifests no longer hardcode S3 bucket names.

Add these keys inside `ZORD_APP_SECRETS_JSON`:

| Service | JSON key |
| --- | --- |
| `zord-edge` | `EDGE_S3_BUCKET` |
| `zord-intent-engine` | `INTENT_S3_BUCKET` |
| `zord-outcome-engine` | `OUTCOME_S3_BUCKET` |
| `zord-evidence` | `EVIDENCE_S3_BUCKET` |

External Secrets copies these values into Kubernetes secret `zord-app-secrets`. The pods still receive the environment variable `S3_BUCKET`, but its value comes from the correct secret key for each service.

## Step By Step: Add `ZORD_EDGE_SIGNING_KEY_JSON`

Click:

`New repository secret`

Secret name:

```text
ZORD_EDGE_SIGNING_KEY_JSON
```

Paste JSON like this:

```json
{
  "ed25519_private.pem": "-----BEGIN PRIVATE KEY-----\nYOUR_REAL_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----"
}
```

Then click:

`Add secret`

## Very Important About Private Key Format

The private key must be one JSON string.

That means line breaks should be written as:

`\n`

Example:

```json
{
  "ed25519_private.pem": "-----BEGIN PRIVATE KEY-----\nLINE1\nLINE2\nLINE3\n-----END PRIVATE KEY-----"
}
```

Do not paste raw multiline YAML there.

## Which Values You Must Change Before Production

You should replace these with real values:

- `POSTGRES_SUPERUSER_PASSWORD`
- `ZORD_VAULT_KEY`
- `INTERNAL_ADMIN_KEY`
- `TOKEN_SECRET`
- `EVIDENCE_SIGNING_PRIVATE_KEY_BASE64`
- `EVIDENCE_ARCHIVE_ENCRYPTION_KEY_BASE64`
- `GEMINI_API_KEYS`
- `EDGE_S3_BUCKET`
- `INTENT_S3_BUCKET`
- `OUTCOME_S3_BUCKET`
- `EVIDENCE_S3_BUCKET`
- `ed25519_private.pem`

You can keep these existing passwords for testing if you want:

- `zord_password`
- `intent_password`
- `relay_password`
- `token_password`
- `outcome_password`
- `evidence_password`
- `zpi_secret`

But for real production, even those should become strong passwords.

## How The Workflow Works

Workflow file:

`.github/workflows/secrets-manager-terraform.yml`

Manual actions available:

- `plan`
- `apply`
- `destroy`

If you choose destroy, you must also set:

```text
confirm_destroy = yes
```

## Step By Step: Run The Workflow

Open:

`GitHub repo -> Actions -> Secret Manager Terraform`

Click:

`Run workflow`

Choose:

```text
action = apply
```

Then run it.

## What Happens During `apply`

The workflow does this:

1. checks out code
2. sets up Terraform
3. logs in to AWS
4. runs `terraform init`
5. runs `terraform validate`
6. runs `terraform apply`
7. creates these AWS secret containers:
   - `zord/app-secrets`
   - `zord/edge-signing-key`
8. reads:
   - `ZORD_APP_SECRETS_JSON`
   - `ZORD_EDGE_SIGNING_KEY_JSON`
9. writes those JSON values into AWS Secrets Manager

So after workflow success, your AWS secret values are ready.

## How To Check It Worked

After the workflow completes:

1. open AWS Console
2. open `Secrets Manager`
3. search for:
   - `zord/app-secrets`
   - `zord/edge-signing-key`

You should see both secrets there.

## What Happens After This

After this workflow succeeds, do the next 2 things:

1. Run the `EKS Terraform` workflow with `apply`
2. Deploy your app repo manifests

The EKS workflow now installs:

- Cluster Autoscaler
- External Secrets Operator

After your app manifests are applied, External Secrets Operator will create these Kubernetes secrets:

- `zord-app-secrets`
- `zord-edge-signing-key`

That means your pods can keep using normal `secretKeyRef` and mounted Kubernetes secrets.

## How To Verify External Secrets Later

After EKS is up and your app manifests are applied, run:

```bash
kubectl get pods -n external-secrets
kubectl get externalsecret -n zord
kubectl get secret -n zord zord-app-secrets
kubectl get secret -n zord zord-edge-signing-key
```

Expected result:

- External Secrets Operator pods are `Running`
- `ExternalSecret` objects exist in namespace `zord`
- Kubernetes secrets `zord-app-secrets` and `zord-edge-signing-key` exist

## How To Destroy With One Click

Yes, this is possible.

Open:

`GitHub repo -> Actions -> Secret Manager Terraform`

Click:

`Run workflow`

Choose:

```text
action = destroy
```

And set:

```text
confirm_destroy = yes
```

Then run it.

This will run:

`terraform destroy`

for this `secret-manager` folder.

## Important Note About Destroy

This destroy removes the Terraform-managed AWS secrets from this folder.

It does **not** destroy:

- EKS cluster
- VPC
- EC2 admin box
- node groups
- ECR

Those are in your `EKS-terraform` stack, not here.

## Local Commands If You Want To Test

From this folder:

```powershell
terraform init -backend=false
terraform validate
```

If using real backend locally:

```powershell
terraform init `
  -backend-config="bucket=<your-tf-state-bucket>" `
  -backend-config="key=secret-manager/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="encrypt=true"
```

Then:

```powershell
terraform plan
```

## Short Summary

You need to do only this:

1. add GitHub secret `ZORD_APP_SECRETS_JSON`
2. add GitHub secret `ZORD_EDGE_SIGNING_KEY_JSON`
3. make sure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `TF_STATE_BUCKET` already exist
4. run GitHub Action with `apply`

After that, AWS Secrets Manager will contain your secret values.
