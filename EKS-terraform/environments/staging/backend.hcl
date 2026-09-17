# Backend configuration — STAGING
# Used as: terraform init -backend-config=environments/staging/backend.hcl
key          = "eks/staging/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
