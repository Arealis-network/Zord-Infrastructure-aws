terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
    # destroy-time finalizer cleanup + webhook-readiness wait
    null = {
      source = "hashicorp/null"
    }
  }
}
