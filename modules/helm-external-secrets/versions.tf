terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
    # Needed to create the ClusterSecretStore custom resource.
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # Short wait so the ESO CRDs are established before the CR is created.
    time = {
      source = "hashicorp/time"
    }
  }
}
