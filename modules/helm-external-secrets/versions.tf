terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
    # Short wait so the ESO CRDs are established before the ClusterSecretStore
    # custom resource is created.
    time = {
      source = "hashicorp/time"
    }
  }
}
