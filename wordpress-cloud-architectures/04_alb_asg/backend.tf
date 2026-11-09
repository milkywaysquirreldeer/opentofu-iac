terraform {
  backend "s3" {
    bucket       = "f2726422-tfstate"
    key          = "backend/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
