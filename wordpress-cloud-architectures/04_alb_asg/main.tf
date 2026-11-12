data "aws_availability_zones" "available" {}

locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  az_count = length(local.azs)
}

resource "aws_vpc" "wp_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "wp_igw" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "wp_public_rt" {
  vpc_id = aws_vpc.wp_vpc.id

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route" "wp_default_route" {
  route_table_id         = aws_route_table.wp_public_rt.id
  gateway_id             = aws_internet_gateway.wp_igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_default_route_table" "wp_default_rtb" {
  default_route_table_id = aws_vpc.wp_vpc.default_route_table_id

  tags = {
    Name = "${var.vpc_name}-default-rtb"
  }
}

resource "aws_subnet" "wp_public_subnet" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.wp_vpc.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(aws_vpc.wp_vpc.cidr_block, 4, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-subnet-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "wp_public_rta" {
  count          = local.az_count
  subnet_id      = aws_subnet.wp_public_subnet[count.index].id
  route_table_id = aws_route_table.wp_public_rt.id
}

resource "aws_subnet" "wp_app_subnet" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.wp_vpc.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(aws_vpc.wp_vpc.cidr_block, 4, (local.az_count + count.index))
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.vpc_name}-app-subnet-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "wp_db_subnet" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.wp_vpc.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(aws_vpc.wp_vpc.cidr_block, 4, ((2 * local.az_count) + count.index))
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.vpc_name}-db-subnet-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "wp_reserved_subnet" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.wp_vpc.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(aws_vpc.wp_vpc.cidr_block, 4, ((3 * local.az_count) + count.index))
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-reserved-subnet-${local.azs[count.index]}"
  }
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
  vpc_id      = aws_vpc.wp_vpc.id

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

resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = aws_subnet.wp_app_subnet[0].id
  security_groups = [module.wp_efs_security_group.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = aws_subnet.wp_app_subnet[1].id
  security_groups = [module.wp_efs_security_group.id]
}

resource "aws_efs_mount_target" "c" {
  file_system_id  = aws_efs_file_system.wp.id
  subnet_id       = aws_subnet.wp_app_subnet[2].id
  security_groups = [module.wp_efs_security_group.id]
}

module "wp_db_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/mysql"
  version = "~> 6.0"

  name        = "WP_DB"
  description = "For WordPress MySQL DB"
  vpc_id      = aws_vpc.wp_vpc.id

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

resource "aws_db_subnet_group" "wp" {
  name       = "wp-db-subnet-group"
  subnet_ids = aws_subnet.wp_db_subnet[*].id
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
  vpc_id      = aws_vpc.wp_vpc.id

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

# Current value is required by user data script in launch template
resource "aws_ssm_parameter" "efs_dns_name" {
  depends_on = [aws_efs_file_system.wp]
  name       = "/A4L/Wordpress/EFSFSID"
  type       = "String"
  value      = aws_efs_file_system.wp.dns_name
}

# Current value is required by user data script in launch template
resource "aws_ssm_parameter" "DBEndpoint" {
  name      = "/A4L/Wordpress/DBEndpoint"
  type      = "String"
  overwrite = true
  value     = aws_db_instance.wp.address
}

# Current value is required by user data script in launch template
resource "aws_ssm_parameter" "alb_dns_name" {
  name  = "/A4L/Wordpress/ALBDNSNAME"
  type  = "String"
  value = aws_lb.wp_web.dns_name
}

resource "aws_launch_template" "wp_web" {
  name                   = "wordpress"
  instance_type          = "t3.nano"
  image_id               = var.wp_web_custom_ami
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
  depends_on = [
    data.aws_ssm_parameter.DBUser,
    data.aws_ssm_parameter.DBPassword,
    data.aws_ssm_parameter.DBName,
    aws_ssm_parameter.alb_dns_name,
    aws_ssm_parameter.DBEndpoint,
    aws_ssm_parameter.efs_dns_name
  ]
  name                      = "A4LWORDPRESSASG"
  max_size                  = 3
  min_size                  = 1
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

  vpc_zone_identifier = aws_subnet.wp_public_subnet[*].id
}

resource "aws_autoscaling_policy" "high_cpu" {
  name                   = "HIGHCPU"
  autoscaling_group_name = aws_autoscaling_group.wp_web.name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 600
}

resource "aws_autoscaling_policy" "low_cpu" {
  name                   = "LOWCPU"
  autoscaling_group_name = aws_autoscaling_group.wp_web.name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 600
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
  period              = "300"
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
  period              = "300"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wp_web.name
  }
}

resource "aws_lb_target_group" "wp_web" {
  name     = "A4LWORDPRESSALBTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wp_vpc.id

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
  vpc_id      = aws_vpc.wp_vpc.id

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
  subnets         = aws_subnet.wp_public_subnet[*].id
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
