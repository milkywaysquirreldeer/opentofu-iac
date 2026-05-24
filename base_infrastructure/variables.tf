variable "aws_region_code" {
  description = "Chooses AWS region for this infrastructure."
  type        = string
  default     = "us-west-2"
}

variable "azA_name" {
  description = "Sets name of Availability Zone A in this region."
  type        = string
  default     = "us-west-2a"
}

variable "azB_name" {
  description = "Sets name of Availability Zone B in this region."
  type        = string
  default     = "us-west-2b"
}

variable "azC_name" {
  description = "Sets name of Availability Zone C in this region."
  type        = string
  default     = "us-west-2c"
}

variable "vpc_name" {
  description = "Sets the custom VPC's Name tag."
  type        = string
  default     = "project-vpc"
}
