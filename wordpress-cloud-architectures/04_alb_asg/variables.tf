variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "asg_enabled_metrics" {
  type        = list(any)
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
