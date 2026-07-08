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

# Queries which subnets are designated as app-tier subnets
data "aws_subnets" "app_tagged" {
  depends_on = [module.vpc]

  filter {
    name   = "tag:Name"
    values = ["${local.subnet_labels.app}-*"]
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

# Required during EC2 instance bootstrap
resource "aws_ssm_parameter" "efs_dns_name" {
  depends_on = [aws_efs_file_system.wp]
  name       = "/A4L/Wordpress/EFSFSID"
  type       = "String"
  value      = aws_efs_file_system.wp.dns_name
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

# Required during EC2 instance bootstrap
resource "aws_ssm_parameter" "DBEndpoint" {
  name      = "/A4L/Wordpress/DBEndpoint"
  type      = "String"
  overwrite = true
  value     = aws_db_instance.wp.address
}

module "wp_web_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "~> 6.0"

  name        = "WP_WEB"
  description = "For WordPress EC2 instance(s)"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_ipv4 = {
    ALL = "0.0.0.0/0"
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

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Creates EC2 Instance for web server and media)
resource "aws_launch_template" "wp_web" {
  name                   = "wordpress"
  instance_type          = "t3.nano"
  image_id               = data.aws_ssm_parameter.al2023_ami.insecure_value
  ebs_optimized          = true
  user_data              = filebase64("${path.root}/files/wp-bootstrap.sh")
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

resource "aws_instance" "wp_web" {
  depends_on = [aws_db_instance.wp, aws_ssm_parameter.efs_dns_name]
  subnet_id  = module.vpc.public_subnets[0]

  launch_template {
    id      = aws_launch_template.wp_web.id
    version = "$Latest"
  }

  tags = {
    Name = "WordPress"
  }
}
