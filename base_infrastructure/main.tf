# Configure the AWS Provider
provider "aws" {
  region = var.aws_region_code
}

# Define nondefault/custom VPC
resource "aws_vpc" "vpc1" {
  cidr_block           = "10.16.0.0/16"
  enable_dns_hostnames = "true"
  tags = {
    Name = var.vpc_name
  }
}

# Define Internet Gateway
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "project-igw"
  }
}

# Define Route Table for web-enabled subnets
resource "aws_route_table" "internet-access" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "rtb-web"
  }
}

# Define Subnets
## Subnets in Availability Zone A
### Reserved Subnet A
resource "aws_subnet" "reserved-A" {
  availability_zone = var.azA_name
  cidr_block        = "10.16.0.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-reserved-A"
  }
}

### DB-tier Subnet A
resource "aws_subnet" "db-A" {
  availability_zone = var.azA_name
  cidr_block        = "10.16.16.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-db-A"
  }
}

### App-tier Subnet A
resource "aws_subnet" "app-A" {
  availability_zone = var.azA_name
  cidr_block        = "10.16.32.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-app-A"
  }
}

### Web-tier Subnet A
resource "aws_subnet" "web-A" {
  availability_zone       = var.azA_name
  cidr_block              = "10.16.48.0/20"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc1.id

  tags = {
    Name = "sn-web-A"
  }
}

## Subnets in Availability Zone B
### Reserved Subnet B
resource "aws_subnet" "reserved-B" {
  availability_zone = var.azB_name
  cidr_block        = "10.16.64.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-reserved-B"
  }
}

### DB-tier Subnet B
resource "aws_subnet" "db-B" {
  availability_zone = var.azB_name
  cidr_block        = "10.16.80.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-db-B"
  }
}

### App-tier Subnet B
resource "aws_subnet" "app-B" {
  availability_zone = var.azB_name
  cidr_block        = "10.16.96.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-app-B"
  }
}

### Web-tier Subnet B
resource "aws_subnet" "web-B" {
  availability_zone       = var.azB_name
  cidr_block              = "10.16.112.0/20"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc1.id

  tags = {
    Name = "sn-web-B"
  }
}

## Subnets in Availability Zone C
### Reserved Subnet C
resource "aws_subnet" "reserved-C" {
  availability_zone = var.azC_name
  cidr_block        = "10.16.128.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-reserved-C"
  }
}

### DB-tier Subnet C
resource "aws_subnet" "db-C" {
  availability_zone = var.azC_name
  cidr_block        = "10.16.144.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-db-C"
  }
}

### App-tier Subnet C
resource "aws_subnet" "app-C" {
  availability_zone = var.azC_name
  cidr_block        = "10.16.160.0/20"
  vpc_id            = aws_vpc.vpc1.id

  tags = {
    Name = "sn-app-C"
  }
}

### Web-tier Subnet C
resource "aws_subnet" "web-C" {
  availability_zone       = var.azC_name
  cidr_block              = "10.16.176.0/20"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc1.id

  tags = {
    Name = "sn-web-C"
  }
}

# Define Route table associations for web subnets
## Route table association for web subnet in AZ-A
resource "aws_route_table_association" "rta-web-A" {
  subnet_id      = aws_subnet.web-A.id
  route_table_id = aws_route_table.internet-access.id
}

## Route table association for web subnet in AZ-B
resource "aws_route_table_association" "rta-web-B" {
  subnet_id      = aws_subnet.web-B.id
  route_table_id = aws_route_table.internet-access.id
}

## Route table association for web subnet in AZ-C
resource "aws_route_table_association" "rta-web-C" {
  subnet_id      = aws_subnet.web-C.id
  route_table_id = aws_route_table.internet-access.id
}
