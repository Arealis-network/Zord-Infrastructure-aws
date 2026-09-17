# Backend configuration — PRODUCTION
# Used as: terraform init -backend-config=environments/production/backend.hcl
#
# State is isolated per environment under one bucket. Locking is S3-native
# (use_lockfile) — no DynamoDB table required.
key          = "eks/production/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
