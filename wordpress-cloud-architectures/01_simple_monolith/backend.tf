terraform {
  backend "s3" {
    bucket       = "40ded79e-tfstate"
    key          = "backend/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
