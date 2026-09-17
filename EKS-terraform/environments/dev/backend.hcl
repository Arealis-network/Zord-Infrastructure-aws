# Backend configuration — DEV
# Used as: terraform init -backend-config=environments/dev/backend.hcl
key          = "eks/dev/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
