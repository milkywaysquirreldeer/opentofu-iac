// Note: In additon to the variables defined in this file, this module
//  also requires appropriate values to be present in the regional
//  SSM Parameter Store for the following parameters:
//    Values required during EC2 bootstrapping (See ./files/wp-bootstrap.sh):
//      /A4L/Wordpress/DBUser (String)
//      /A4L/Wordpress/DBName (String)
//      /A4L/Wordpress/DBEndpoint (String)
//      /A4L/Wordpress/RDSCertificateBundle (String,
//        e.g. https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem)
//      /A4L/Wordpress/DBPassword (SecureString)

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

variable "wp_web_custom_ami" {
  type        = string
  description = "Custom AMI to use for WP instances"
}

variable "asg_enabled_metrics" {
  type        = list(string)
  description = "Specifies which CloudWatch metrics to enable for monitoring and scaling of the auto scaling group created in this module"
  default = [
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupAndWarmPoolTotalCapacity",
    "GroupTerminatingRetainedCapacity",
    "WarmPoolWarmedCapacity",
    "WarmPoolTotalCapacity",
    "GroupMinSize",
    "GroupTotalCapacity",
    "GroupDesiredCapacity",
    "GroupTotalInstances",
    "GroupStandbyCapacity",
    "GroupPendingInstances",
    "GroupAndWarmPoolDesiredCapacity",
    "WarmPoolTerminatingCapacity",
    "GroupStandbyInstances",
    "WarmPoolPendingCapacity",
    "WarmPoolDesiredCapacity",
    "WarmPoolPendingRetainedCapacity",
    "GroupPendingCapacity",
    "WarmPoolMinSize",
    "WarmPoolTerminatingRetainedCapacity",
    "GroupTerminatingRetainedInstances",
    "GroupInServiceInstances",
    "GroupInServiceCapacity",
    "GroupMaxSize"
  ]
}
