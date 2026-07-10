provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Terraform = "true"
      Project   = "WordPress"
    }
  }
}

data "aws_availability_zones" "available" {}

locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  vpc_name = "WP-vpc"

  subnet_labels = {
    app      = "${local.vpc_name}-app",
    db       = "${local.vpc_name}-db",
    public   = "${local.vpc_name}-web",
    reserved = "${local.vpc_name}-reserved"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v6.6.1"

  name                    = local.vpc_name
  azs                     = local.azs
  cidr                    = "10.21.0.0/16"
  map_public_ip_on_launch = true

  private_subnets = [
    "10.21.16.0/20", "10.21.32.0/20", "10.21.48.0/20",
    "10.21.80.0/20", "10.21.96.0/20", "10.21.112.0/20",
    "10.21.144.0/20", "10.21.160.0/20", "10.21.176.0/20"
  ]

  private_subnet_names = [
    "${local.subnet_labels.reserved}-${local.azs[0]}",
    "${local.subnet_labels.reserved}-${local.azs[1]}",
    "${local.subnet_labels.reserved}-${local.azs[2]}",
    "${local.subnet_labels.db}-${local.azs[0]}",
    "${local.subnet_labels.db}-${local.azs[1]}",
    "${local.subnet_labels.db}-${local.azs[2]}",
    "${local.subnet_labels.app}-${local.azs[0]}",
    "${local.subnet_labels.app}-${local.azs[1]}",
    "${local.subnet_labels.app}-${local.azs[2]}"
  ]

  public_subnets = ["10.21.0.0/20", "10.21.64.0/20", "10.21.128.0/20"]

  public_subnet_names = [
    for az in local.azs : "${local.subnet_labels.public}-${az}"
  ]
}

resource "aws_efs_file_system" "wp" {
  creation_token   = "A4L-WORDPRESS-CONTENT"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "A4L-WORDPRESS-CONTENT"
  }
}

module "wp_efs_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/nfs"
  version = "~> 6.0"

  name        = "WP_EFS"
  description = "For WordPress EFS mount targets"
  vpc_id      = module.vpc.vpc_id

  ingress_referenced_security_group_id = {
    WP_WEB = module.wp_web_security_group.id
  }

  egress_rules = {
    "all/WP_WEB" = {
      ip_protocol                  = "-1"
      referenced_security_group_id = module.wp_web_security_group.id
    }
  }

  tags = {
    Name = "WP_EFS"
  }
}

# Queries which subnets are designated as app-tier subnets (used while defining
#  EFS mount targets)
data "aws_subnets" "app_tagged" {
  depends_on = [module.vpc]

  filter {
    name   = "tag:Name"
    values = ["${local.subnet_labels.app}-*"]
  }
}

resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = data.aws_subnets.app_tagged.ids[0]
  security_groups = [module.wp_efs_security_group.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = data.aws_subnets.app_tagged.ids[1]
  security_groups = [module.wp_efs_security_group.id]
}

resource "aws_efs_mount_target" "c" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = data.aws_subnets.app_tagged.ids[2]
  security_groups = [module.wp_efs_security_group.id]
}

module "wp_db_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/mysql"
  version = "~> 6.0"

  name        = "WP_DB"
  description = "For WordPress MySQL DB"
  vpc_id      = module.vpc.vpc_id

  ingress_referenced_security_group_id = {
    WP_WEB = module.wp_web_security_group.id
  }

  egress_rules = {
    "all/WP_WEB" = {
      ip_protocol                  = "-1"
      referenced_security_group_id = module.wp_web_security_group.id
    }
  }

  tags = {
    Name = "WP_DB"
  }
}

# Queries which subnets are designated as database subnets
data "aws_subnets" "db_tagged" {
  depends_on = [module.vpc]

  filter {
    name   = "tag:Name"
    values = ["${local.subnet_labels.db}-*"]
  }
}

resource "aws_db_subnet_group" "wp" {
  name       = "wp-db-subnet-group"
  subnet_ids = data.aws_subnets.db_tagged.ids
}

data "aws_ssm_parameter" "DBUser" {
  name = "/A4L/Wordpress/DBUser"
}

data "aws_ssm_parameter" "DBPassword" {
  name = "/A4L/Wordpress/DBPassword"
}

data "aws_ssm_parameter" "DBName" {
  name = "/A4L/Wordpress/DBName"
}

resource "aws_db_instance" "wp" {
  availability_zone         = local.azs[0]
  allocated_storage         = 5
  db_name                   = data.aws_ssm_parameter.DBName.value
  db_subnet_group_name      = aws_db_subnet_group.wp.name
  engine                    = "mysql"
  engine_version            = "8.4"
  final_snapshot_identifier = "wordpress-db"
  identifier                = "wordpress-db"
  instance_class            = "db.t3.micro"
  network_type              = "IPV4"
  username                  = data.aws_ssm_parameter.DBUser.value
  password                  = data.aws_ssm_parameter.DBPassword.value
  vpc_security_group_ids    = [module.wp_db_security_group.id]
}

module "wp_web_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 6.0"

  name        = "WP_WEB"
  description = "For WordPress EC2 instance(s)"
  vpc_id      = module.vpc.vpc_id

  ingress_referenced_security_group_id = {
    WP_ALB = module.wp_alb_security_group.id
  }

  egress_rules = {
    "all/ALL" = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = {
    Name = "WP_WEB"
  }
}

module "iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "v6.6.1"

  name = "wp-instance-role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      actions = [
        "sts:AssumeRole",
      ]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "aws_iam_instance_profile" "wp_web" {
  name = "wp-instance-profile"
  role = module.iam_role.name
}

data "aws_ssm_parameter" "wp_custom_ami" {
  name = "/A4L/Wordpress/CustomAMI"
}

# Current value is read by user data script in launch template
resource "aws_ssm_parameter" "efs_dns_name" {
  depends_on = [aws_efs_file_system.wp]
  name       = "/A4L/Wordpress/EFSFSID"
  type       = "String"
  value      = aws_efs_file_system.wp.dns_name
}

# Current value is read by user data script in launch template
resource "aws_ssm_parameter" "DBEndpoint" {
  name      = "/A4L/Wordpress/DBEndpoint"
  type      = "String"
  overwrite = true
  value     = aws_db_instance.wp.address
}

# Current value is read by user data script in launch template
resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/A4L/Wordpress/ALBDNSNAME"
  type  = "String"
  value = aws_lb.wp_web.dns_name
}

resource "aws_launch_template" "wp_web" {
  name                   = "wordpress"
  instance_type          = "t3.nano"
  image_id               = data.aws_ssm_parameter.wp_custom_ami.value
  ebs_optimized          = true
  user_data              = filebase64("${path.root}/files/wp-bootstrap-custom-ami.sh")
  update_default_version = true
  vpc_security_group_ids = [module.wp_web_security_group.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "standard"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.wp_web.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

resource "aws_autoscaling_group" "wp_web" {
  name                      = "A4LWORDPRESSASG"
  max_size                  = 2
  min_size                  = 0
  desired_capacity          = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  enabled_metrics           = var.asg_enabled_metrics
  metrics_granularity       = "1Minute"

  launch_template {
    id      = aws_launch_template.wp_web.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [desired_capacity, target_group_arns]
  }

  tag {
    key                 = "Name"
    propagate_at_launch = "true"
    value               = "WordPress-ASG"
  }

  vpc_zone_identifier = module.vpc.public_subnets
}

resource "aws_autoscaling_policy" "high_cpu" {
  name                   = "HIGHCPU"
  autoscaling_group_name = aws_autoscaling_group.wp_web.name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
}

resource "aws_autoscaling_policy" "low_cpu" {
  name                   = "LOWCPU"
  autoscaling_group_name = aws_autoscaling_group.wp_web.name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_description   = "Monitors CPU utilization for A4LWORDPRESSASG"
  alarm_actions       = [aws_autoscaling_policy.high_cpu.arn]
  alarm_name          = "WORDPRESSHIGHCPU"
  comparison_operator = "GreaterThanThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "40"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wp_web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_description   = "Monitors CPU utilization for A4LWORDPRESSASG"
  alarm_actions       = [aws_autoscaling_policy.low_cpu.arn]
  alarm_name          = "WORDPRESSLOWCPU"
  comparison_operator = "LessThanThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "40"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wp_web.name
  }
}

resource "aws_lb_target_group" "wp_web" {
  name     = "A4LWORDPRESSALBTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path = "/"
  }
}

resource "aws_autoscaling_attachment" "wp_web" {
  autoscaling_group_name = aws_autoscaling_group.wp_web.name
  lb_target_group_arn    = aws_lb_target_group.wp_web.arn
}

module "wp_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 6.0"

  name        = "WP_ALB"
  description = "For WordPress ALB nodes"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_ipv4 = {
    ALL = "0.0.0.0/0"
  }

  egress_rules = {
    "all/WP_WEB" = {
      ip_protocol                  = "-1"
      referenced_security_group_id = module.wp_web_security_group.id
    }
  }

  tags = {
    Name = "WP_ALB"
  }
}

resource "aws_lb" "wp_web" {
  name            = "A4LWORDPRESSALB"
  security_groups = [module.wp_alb_security_group.id]
  subnets         = module.vpc.public_subnets
}

resource "aws_lb_listener" "wp_web" {
  load_balancer_arn = aws_lb.wp_web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wp_web.arn
  }
}
