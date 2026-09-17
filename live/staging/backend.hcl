# Shared backend settings for ALL staging components.
# The per-component state key is supplied by the pipeline, e.g.
#   -backend-config="key=eks/staging/01-foundation.tfstate"
#
# Locking is S3-native (use_lockfile) - no DynamoDB table required.
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
