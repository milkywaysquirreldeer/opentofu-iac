# IP addressing variables
variable "vpc_cidr" {
  description =  "Defines 1 CIDR block to assign to this VPC."
  type = string

  # Example: "10.0.0.0/16"
}

variable "azA_subnet_cidrs" {
  description =  "A list of 4 IP address ranges for the 4 subnets in AZ A"
  type = list(string)

  /* Example:
  [
    "10.0.0.0/20",
    "10.0.16.0/20",
    "10.0.32.0/20",
    "10.0.48.0/20"
  ]
  */

}

variable "azB_subnet_cidrs" {
  description =  "A list of 4 IP address ranges for the 4 subnets in AZ B"
  type = list(string)

  /* Example:
  [
    "10.0.64.0/20",
    "10.0.80.0/20",
    "10.0.96.0/20",
    "10.0.112.0/20"
  ]
  */

}

variable "azC_subnet_cidrs" {
  description =  "A list of 4 IP address ranges for the 4 subnets in AZ C"
  type = list(string)
  /*

  Example:
  [
    "10.0.128.0/20",
    "10.0.144.0/20",
    "10.0.160.0/20",
    "10.0.176.0/20"
  ]
  */

}

# Other variables
variable "vpc_name" {
  description = "Defines the Name tag assigned to the VPC."
  type = string
  default = ""
}
