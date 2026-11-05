terraform {
  backend "s3" {
    bucket       = "9a4640ed-tfstate"
    key          = "backend/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
