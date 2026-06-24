terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = "~> 1.12"

  backend "s3" {
    bucket       = "elastic-wordpress-tf-state-856521070868-us-west-2-an"
    key          = "backend/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
