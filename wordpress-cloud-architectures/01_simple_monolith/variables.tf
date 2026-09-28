variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "vpc_cidr" {
  type    = string
  default = "10.21.0.0/16"
}

variable "vpc_name" {
  type    = string
  default = "WP-vpc"
}
