resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = "true"

  tags = {
    Name = var.name_tag
  }
}

# Retrieves info about the available AZs in the Region being used
data "aws_availability_zones" "available" {
  state = "available"
}

# Subnets
## in Availability Zone A
resource "aws_subnet" "reserved_A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs[0]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-reserved-A"
  }
}

resource "aws_subnet" "db_A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs[1]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-db-A"
  }
}

resource "aws_subnet" "app_A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs[2]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-app-A"
  }
}

resource "aws_subnet" "web_A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs[3]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    Name = "sn-web-A"
  }
}

## in Availability Zone B
resource "aws_subnet" "reserved_B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs[0]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-reserved-B"
  }
}

resource "aws_subnet" "db_B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs[1]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-db-B"
  }
}

resource "aws_subnet" "app_B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs[2]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-app-B"
  }
}

resource "aws_subnet" "web_B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs[3]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    Name = "sn-web-B"
  }
}

## in Availability Zone C
resource "aws_subnet" "reserved_C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = var.azC_subnet_cidrs[0]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-reserved-C"
  }
}

resource "aws_subnet" "db_C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = var.azC_subnet_cidrs[1]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-db-C"
  }
}

resource "aws_subnet" "app_C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = var.azC_subnet_cidrs[2]
  vpc_id            = aws_vpc.main.id

  tags = {
    Name = "sn-app-C"
  }
}

resource "aws_subnet" "web_C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block              = var.azC_subnet_cidrs[3]
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    Name = "sn-web-C"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rtb-public-subnets"
  }
}

resource "aws_route_table_association" "web_A" {
  subnet_id      = aws_subnet.web_A.id
  route_table_id = aws_route_table.public_subnets.id
}

resource "aws_route_table_association" "web_B" {
  subnet_id      = aws_subnet.web_B.id
  route_table_id = aws_route_table.public_subnets.id
}

resource "aws_route_table_association" "web_C" {
  subnet_id      = aws_subnet.web_C.id
  route_table_id = aws_route_table.public_subnets.id
}
