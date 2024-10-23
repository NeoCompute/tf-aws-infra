provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# VPC
resource "aws_vpc" "vpc-01" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
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

# Security Group for DB 
resource "aws_security_group" "database-security-group" {
  vpc_id = aws_vpc.vpc-01.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application-security-group.id]
  } # allowing incoming connection from EC2 instance security group


  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application-security-group.id]
  }

  tags = {
    Name = "database-security-group"
  }
}

# Parameter Group for DB
resource "aws_db_parameter_group" "postgresql_parameter_group" {
  name        = "csye6225-postgresql-params"
  family      = "postgres16"
  description = "DB Parameter Group for webapp"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }

  tags = {
    Name = "csye6225-postgresql-params"
  }
}

# DB Subnet Group (use private subnets)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "csye6225-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id # Using private subnets for RDS instance

  tags = {
    Name = "csye6225-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 20
  instance_class         = "db.t4g.micro"
  engine                 = "postgres"
  engine_version         = "16.1"
  identifier             = "csye6225"
  db_name                = var.database_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.postgresql_parameter_group.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.database-security-group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name # Using DB Subnet Group
  multi_az               = false

  tags = {
    Name = "csye6225"
  }
}

# EC2 instance using custom AMI
resource "aws_instance" "webapp-instance" {
  ami           = var.custom_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public_subnets[0].id
  key_name      = var.key_name
  depends_on    = [aws_db_instance.rds_instance]

  vpc_security_group_ids = [aws_security_group.application-security-group.id]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  user_data = templatefile("./scripts/user_data_script.sh", {
    DB_HOST     = substr(aws_db_instance.rds_instance.endpoint, 0, length(aws_db_instance.rds_instance.endpoint) - 5)
    DB_USER     = var.db_username
    DB_PASSWORD = var.db_password
    DB_NAME     = var.database_name
    APP_PORT    = var.application_port
  })
  tags = {
    Name = "webapp-instance"
  }
}