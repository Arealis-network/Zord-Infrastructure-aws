terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    helm = {
      source = "hashicorp/helm"
    }
    # destroy-time ALB/ENI cleanup so the VPC destroy doesn't fail on
    # orphaned load balancers ("mapped public address(es)" / "subnet has dependencies")
    null = {
      source = "hashicorp/null"
    }
  }
}
