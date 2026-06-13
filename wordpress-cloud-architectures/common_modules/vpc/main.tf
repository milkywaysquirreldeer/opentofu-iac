# Retrieves info about the available AZs in the Region being used
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = "true"
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw"
  }
}


# Subnets
## in Availability Zone A
resource "aws_subnet" "reserved-A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs.0
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-reserved-A"
  }
}

resource "aws_subnet" "db-A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs.1
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-db-A"
  }
}

resource "aws_subnet" "app-A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs.2
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-app-A"
  }
}

resource "aws_subnet" "web-A" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = var.azA_subnet_cidrs.3
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
  tags = {
    Name = "sn-web-A"
  }
}

## in Availability Zone B
resource "aws_subnet" "reserved-B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs.0
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-reserved-B"
  }
}

resource "aws_subnet" "db-B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs.1
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-db-B"
  }
}

resource "aws_subnet" "app-B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs.2
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-app-B"
  }
}

resource "aws_subnet" "web-B" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = var.azB_subnet_cidrs.3
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
  tags = {
    Name = "sn-web-B"
  }
}

## in Availability Zone C
resource "aws_subnet" "reserved-C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = var.azC_subnet_cidrs.0
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-reserved-C"
  }
}

resource "aws_subnet" "db-C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = var.azC_subnet_cidrs.1
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-db-C"
  }
}

resource "aws_subnet" "app-C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block        = var.azC_subnet_cidrs.2
  vpc_id            = aws_vpc.vpc.id
  tags = {
    Name = "sn-app-C"
  }
}

resource "aws_subnet" "web-C" {
  availability_zone = data.aws_availability_zones.available.names[2]
  cidr_block              = var.azC_subnet_cidrs.3
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc.id
  tags = {
    Name = "sn-web-C"
  }
}

# Route table for public subnets
resource "aws_route_table" "rt-public-subnets" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "rtb-public-subnets"
  }
}

# Route table associations for public subnets
resource "aws_route_table_association" "rta-web-A" {
  subnet_id      = aws_subnet.web-A.id
  route_table_id = aws_route_table.rt-public-subnets.id
}

resource "aws_route_table_association" "rta-web-B" {
  subnet_id      = aws_subnet.web-B.id
  route_table_id = aws_route_table.rt-public-subnets.id
}

resource "aws_route_table_association" "rta-web-C" {
  subnet_id      = aws_subnet.web-C.id
  route_table_id = aws_route_table.rt-public-subnets.id
}
