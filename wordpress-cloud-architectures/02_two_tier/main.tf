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

resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "${aws_vpc.wp_vpc.tags.Name}-eip"
  }

  depends_on = [aws_internet_gateway.wp_igw]
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
  map_public_ip_on_launch = false # use eip

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
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.vpc_name}-reserved-subnet-${local.azs[count.index]}"
  }
}

module "wp_db_security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "v6.0.0"
  name        = "WP_DB"
  description = "Allow MySQL from WordPress web SG"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress_rules = {
    mysql-WP_WEB = {
      from_port                    = 3306
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.wp_web_security_group.id
      description                  = "MySQL traffic from WordPress web SG"
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
    Name = "WP_DB"
  }
}

resource "aws_db_subnet_group" "wp" {
  name       = "wp-db-subnet-group"
  subnet_ids = aws_subnet.wp_public_subnet[*].id
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

# Will be referenced during EC2 instance bootstrap process
resource "aws_ssm_parameter" "DBEndpoint" {
  name      = "/A4L/Wordpress/DBEndpoint"
  type      = "String"
  overwrite = true
  value     = aws_db_instance.wp.address
}

module "wp_web_security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "v6.0.0"
  name        = "WP_WEB"
  description = "Allow HTTP from all"
  vpc_id      = aws_vpc.wp_vpc.id

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
  depends_on = [aws_db_instance.wp]
  subnet_id  = aws_subnet.wp_public_subnet[0].id

  launch_template {
    id      = aws_launch_template.wp_web.id
    version = "$Latest"
  }

  tags = {
    Name = "WordPress"
  }
}

resource "aws_eip_association" "wp_web" {
  allocation_id        = aws_eip.eip.id
  network_interface_id = aws_instance.wp_web.primary_network_interface_id
}

