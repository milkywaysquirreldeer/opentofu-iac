provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source   = "${path.root}/../common_modules/vpc"
  name_tag = "WP_VPC"
  vpc_cidr = "10.21.0.0/16"
  azA_subnet_cidrs = [
    "10.21.0.0/20",
    "10.21.16.0/20",
    "10.21.32.0/20",
    "10.21.48.0/20"
  ]

  azB_subnet_cidrs = [
    "10.21.64.0/20",
    "10.21.80.0/20",
    "10.21.96.0/20",
    "10.21.112.0/20"
  ]

  azC_subnet_cidrs = [
    "10.21.128.0/20",
    "10.21.144.0/20",
    "10.21.160.0/20",
    "10.21.176.0/20"
  ]
}

# Security group for monolithic EC2 Instance
resource "aws_security_group" "wp_web" {
  name        = "wp-web"
  description = "Allow HTTP from all"
  vpc_id      = module.vpc.id

  tags = {
    Name = "WP_WEB"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.wp_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.wp_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

module "wp-instance-role" {
  source = "${path.root}/../common_modules/iam/wp-instance-role"
}

resource "aws_iam_instance_profile" "wp" {
  name = "wp-instance-profile"
  role = module.wp-instance-role.name
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Creates monolithic EC2 Instance (web server, DB, and media)
resource "aws_launch_template" "wp" {
  name                   = "wordpress"
  instance_type          = "t3.nano"
  image_id               = data.aws_ssm_parameter.al2023_ami.insecure_value
  ebs_optimized          = true
  user_data              = filebase64("${path.root}/user-data/wp-bootstrap.sh")
  vpc_security_group_ids = [aws_security_group.wp_web.id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "standard"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.wp.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

resource "aws_instance" "wp" {
  subnet_id = module.vpc.subnet_id_web_A

  launch_template {
    id = aws_launch_template.wp.id
  }

  tags = {
    Name = "WordPress"
  }
}
