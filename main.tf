provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# VPC
resource "aws_vpc" "vpc-01" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpc-01"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "ig-01" {
  vpc_id = aws_vpc.vpc-01.id
  tags = {
    Name = "ig-01"
  }
}

# Public Subnets in 3 Availability Zones 
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc-01.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets in 3 Availability Zones
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vpc-01.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc-01.id
  tags = {
    Name = "public-route-table"
  }
}

# A route in the Public Route Table that sends traffic to the Internet Gateway
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig-01.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_associations" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Private Route Table (no internet route)
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc-01.id
  tags = {
    Name = "private-route-table"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_associations" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Group for EC2 instance
resource "aws_security_group" "application-security-group" {
  vpc_id = aws_vpc.vpc-01.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.application_port
    to_port     = var.application_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application-security-group"
  }
}

# EC2 instance using custom AMI
resource "aws_instance" "webapp-instance" {
  ami           = var.custom_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnets[0].id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.application-security-group.id]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "webapp-instance"
  }
}
