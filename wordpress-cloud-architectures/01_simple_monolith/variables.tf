// Note: In additon to the variables defined in this file, this module
//  also requires appropriate values to be present in the regional
//  SSM Parameter Store for the following parameters:
//    /A4L/Wordpress/DBUser (String)
//    /A4L/Wordpress/DBName (String)
//    /A4L/Wordpress/DBEndpoint (String)
//    /A4L/Wordpress/DBPassword (SecureString)
//    /A4L/Wordpress/DBRootPassword (SecureString)
//  These values are required during EC2 bootstrapping (See ./files/wp-bootstrap.sh)

variable "aws_region" {
  type        = string
  description = "Region to set in AWS provider"
  default     = "us-west-2"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block (defaults to '10.21.0.0/16)"
  default     = "10.21.0.0/16"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to create (defaults to 'wp-vpc')"
  default     = "WP-vpc"
}
