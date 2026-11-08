terraform {
  backend "s3" {
    bucket       = "e27b139a-tfstate"
    key          = "backend/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
