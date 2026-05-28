# Secret Manager Terraform Guide

This folder is for AWS Secrets Manager.

This Terraform code does **not** create your EKS cluster.

This folder only creates these 2 AWS Secrets Manager secret containers per environment:

- `staging/zord/app-secrets`
- `staging/zord/edge-signing-key`
- `production/zord/app-secrets`
- `production/zord/edge-signing-key`

Then GitHub Actions will put the real secret values inside them.

That means this flow is:

1. Terraform creates the secret names in AWS (prefixed by environment)
2. GitHub Actions reads your GitHub secrets
3. GitHub Actions writes the real JSON values into AWS Secrets Manager

This is good because your real secrets do not get stored in Terraform state.

## Multi-Environment Support

This stack supports two environments using the same code:

- **staging**
- **production**

Each environment gets:

- Its own secret names (prefixed with `staging/` or `production/`)
- Its own Terraform state file
- Its own GitHub secrets for values

You choose the environment from the workflow dropdown when you click Run workflow.

## Where This Fits In The Full Flow

Your full deployment flow is:

1. Run `Secret Manager Terraform` with environment = `staging`, action = `apply`
2. Run `EKS Terraform` with environment = `staging`, action = `apply`
3. Deploy the app manifests from your app repo targeting the staging cluster

Then for production:

1. Run `Secret Manager Terraform` with environment = `production`, action = `apply`
2. Run `EKS Terraform` with environment = `production`, action = `apply`
3. Deploy the app manifests from your app repo targeting the production cluster

EKS workflow installs External Secrets Operator automatically.

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
- `ZORD_APP_SECRETS_JSON_STAGING`
- `ZORD_APP_SECRETS_JSON_PRODUCTION`
- `ZORD_EDGE_SIGNING_KEY_JSON_STAGING`
- `ZORD_EDGE_SIGNING_KEY_JSON_PRODUCTION`

## What Each GitHub Secret Means

### `AWS_ACCESS_KEY_ID`

Your AWS access key ID.

### `AWS_SECRET_ACCESS_KEY`

Your AWS secret access key.

### `TF_STATE_BUCKET`

The S3 bucket name where Terraform remote state is stored.

State keys used by the workflow:

- `secret-manager/staging/terraform.tfstate`
- `secret-manager/production/terraform.tfstate`

### `ZORD_APP_SECRETS_JSON_STAGING`

JSON string for the staging app secrets. Becomes the value of AWS secret:

`staging/zord/app-secrets`

### `ZORD_APP_SECRETS_JSON_PRODUCTION`

JSON string for the production app secrets. Becomes the value of AWS secret:

`production/zord/app-secrets`

### `ZORD_EDGE_SIGNING_KEY_JSON_STAGING`

JSON string for the staging edge signing key. Becomes the value of AWS secret:

`staging/zord/edge-signing-key`

### `ZORD_EDGE_SIGNING_KEY_JSON_PRODUCTION`

JSON string for the production edge signing key. Becomes the value of AWS secret:

`production/zord/edge-signing-key`

## Step By Step: Add `ZORD_APP_SECRETS_JSON_STAGING`

Open GitHub:

`Settings -> Secrets and variables -> Actions`

Click:

`New repository secret`

Secret name:

```text
ZORD_APP_SECRETS_JSON_STAGING
```

Paste one full JSON value like this:

```json
{
  "POSTGRES_SUPERUSER_PASSWORD": "your-staging-postgres-admin-password",
  "EDGE_DB_PASSWORD": "zord_password",
  "INTENT_DB_PASSWORD": "intent_password",
  "RELAY_DB_PASSWORD": "relay_password",
  "TOKEN_DB_PASSWORD": "token_password",
  "OUTCOME_DB_PASSWORD": "outcome_password",
  "EVIDENCE_DB_PASSWORD": "evidence_password",
  "INTELLIGENCE_DB_PASSWORD": "zpi_secret",
  "ZORD_VAULT_KEY": "your-staging-vault-key",
  "INTERNAL_ADMIN_KEY": "your-staging-admin-key",
  "MASTER_KEY": "W2MSQaooUlXVmVxGB7NgU06keCyKgQ+NlbdaDHCERAE=",
  "TOKEN_SECRET": "your-staging-base64-token-secret",
  "EVIDENCE_SIGNING_PRIVATE_KEY_BASE64": "your-staging-base64-evidence-private-key",
  "EVIDENCE_ARCHIVE_ENCRYPTION_KEY_BASE64": "your-staging-base64-archive-key",
  "GEMINI_API_KEYS": "your-staging-gemini-key-1,your-staging-gemini-key-2",
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

Do the same for `ZORD_APP_SECRETS_JSON_PRODUCTION` with your production values.

## Step By Step: Add `ZORD_EDGE_SIGNING_KEY_JSON_STAGING`

Click:

`New repository secret`

Secret name:

```text
ZORD_EDGE_SIGNING_KEY_JSON_STAGING
```

Paste JSON like this:

```json
{
  "ed25519_private.pem": "-----BEGIN PRIVATE KEY-----\nYOUR_STAGING_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----"
}
```

Then click:

`Add secret`

Do the same for `ZORD_EDGE_SIGNING_KEY_JSON_PRODUCTION` with your production key.

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

For production secrets, you should use strong, unique values for:

- `POSTGRES_SUPERUSER_PASSWORD`
- `ZORD_VAULT_KEY`
- `INTERNAL_ADMIN_KEY`
- `TOKEN_SECRET`
- `EVIDENCE_SIGNING_PRIVATE_KEY_BASE64`
- `EVIDENCE_ARCHIVE_ENCRYPTION_KEY_BASE64`
- `GEMINI_API_KEYS`
- `ed25519_private.pem`
- All database passwords

For staging, you can use test values.

## How The Workflow Works

Workflow file:

`.github/workflows/secrets-manager-terraform.yml`

When you click Run workflow, you choose:

```
Environment: [staging | production]
Action:      [plan | apply | destroy]
```

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
environment = staging
action = apply
```

Then run it.

## What Happens During `apply`

The workflow does this:

1. Checks out code
2. Sets up Terraform
3. Logs in to AWS
4. Runs `terraform init` with environment-specific state key
5. Runs `terraform validate`
6. Runs `terraform apply` with `TF_VAR_environment` set
7. Creates these AWS secret containers (for staging example):
   - `staging/zord/app-secrets`
   - `staging/zord/edge-signing-key`
8. Reads the matching GitHub secret:
   - `ZORD_APP_SECRETS_JSON_STAGING`
   - `ZORD_EDGE_SIGNING_KEY_JSON_STAGING`
9. Writes those JSON values into AWS Secrets Manager

So after workflow success, your AWS secret values are ready for that environment.

## How To Check It Worked

After the workflow completes:

1. Open AWS Console
2. Open `Secrets Manager`
3. Search for:
   - `staging/zord/app-secrets` (if you ran staging)
   - `production/zord/app-secrets` (if you ran production)

You should see the secrets there.

## How To Destroy One Environment

Open:

`GitHub repo -> Actions -> Secret Manager Terraform`

Click:

`Run workflow`

Choose:

```text
environment = staging
action = destroy
confirm_destroy = yes
```

Then run it.

This will destroy only the staging secrets. Production is untouched.

## Important Note About Destroy

This destroy removes only the Terraform-managed AWS secrets for the selected environment.

It does **not** destroy:

- The other environment's secrets
- EKS cluster
- VPC
- EC2 admin box
- Node groups

Those are in your `EKS-terraform` stack, not here.

## Terraform State Files

Each environment has its own state file:

| Environment | State Key |
|---|---|
| staging | `secret-manager/staging/terraform.tfstate` |
| production | `secret-manager/production/terraform.tfstate` |

This means staging and production are fully independent. You can destroy one without affecting the other.

## Local Commands If You Want To Test

From this folder:

```powershell
terraform init -backend=false
terraform validate
```

If using real backend locally for staging:

```powershell
terraform init `
  -backend-config="bucket=<your-tf-state-bucket>" `
  -backend-config="key=secret-manager/staging/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="encrypt=true"
```

Then:

```powershell
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

For production:

```powershell
terraform init -reconfigure `
  -backend-config="bucket=<your-tf-state-bucket>" `
  -backend-config="key=secret-manager/production/terraform.tfstate" `
  -backend-config="region=ap-south-1" `
  -backend-config="encrypt=true"

terraform plan -var="environment=production"
terraform apply -var="environment=production"
```

## Short Summary

You need to do only this:

1. Add GitHub secrets:
   - `ZORD_APP_SECRETS_JSON_STAGING`
   - `ZORD_APP_SECRETS_JSON_PRODUCTION`
   - `ZORD_EDGE_SIGNING_KEY_JSON_STAGING`
   - `ZORD_EDGE_SIGNING_KEY_JSON_PRODUCTION`
2. Make sure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `TF_STATE_BUCKET` already exist
3. Run GitHub Action with environment + apply

After that, AWS Secrets Manager will contain your secret values for that environment.
