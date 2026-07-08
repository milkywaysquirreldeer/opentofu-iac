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
    "${local.subnet_labels.public}-${local.azs[0]}",
    "${local.subnet_labels.public}-${local.azs[1]}",
    "${local.subnet_labels.public}-${local.azs[2]}"
  ]
}

module "wp_web_security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "v6.0.0"
  name        = "WP_WEB"
  description = "Allow HTTP from all"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    http-ALL = {
      from_port   = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from ALL"
    }
    all-SG = {
      ip_protocol                  = "-1"
      referenced_security_group_id = "self"
      description                  = "All traffic from members of this SG"
    }
  }

  egress_rules = {
    all = {
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

resource "aws_iam_instance_profile" "wp" {
  name = "wp-instance-profile"
  role = module.iam_role.name
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
  user_data              = filebase64("${path.root}/files/wp-bootstrap.sh")
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
    name = aws_iam_instance_profile.wp.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

resource "aws_instance" "wp" {
  subnet_id = module.vpc.public_subnets[0]

  launch_template {
    id = aws_launch_template.wp.id
  }

  tags = {
    Name = "WordPress"
  }
}
