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

  iam_instance_profile   = aws_iam_instance_profile.cloudwatch_agent_profile.name
  vpc_security_group_ids = [aws_security_group.application-security-group.id]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  user_data = templatefile("./scripts/user_data_script.sh", {
    DB_HOST        = substr(aws_db_instance.rds_instance.endpoint, 0, length(aws_db_instance.rds_instance.endpoint) - 5)
    DB_USER        = var.db_username
    DB_PASSWORD    = var.db_password
    DB_NAME        = var.database_name
    APP_PORT       = var.application_port
    ENVIRONMENT    = var.webapp_environment
    S3_BUCKET_NAME = aws_s3_bucket.bucket.bucket
  })
  tags = {
    Name = "webapp-instance"
  }
}

resource "random_uuid" "bucket_name" {}

resource "aws_iam_policy" "s3_bucket_policy" {
  name        = "S3BucketAccessPolicy"
  description = "Policy to allow access to S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"
        ]
      }
    ]
  })
} // IAM policy for S3 bucket

resource "aws_iam_role" "s3_access_role" {
  name = "S3AccessRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.s3_access_role.name
  policy_arn = aws_iam_policy.s3_bucket_policy.arn
} // creating IAM Role and attaching the policy

resource "aws_kms_key" "kms_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "bucket" {
  bucket        = random_uuid.bucket_name.result
  force_destroy = true
} // Creating S3 bucket with random UUID

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_s3_server_side_config" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.bucket]

  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle_rule" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "TransitionToStandardIA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
} // Transition of storage class to IA from Standard



# Route 53 Record for `dev` subdomain
resource "aws_route53_record" "subdomain_update" {
  zone_id = var.hosted_zone_id
  name    = var.subdomain_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.webapp-instance.public_ip]
}


# IAM Role for cloudwatch agent
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name        = "CloudWatchAgentPolicy"
  description = "Policy for CloudWatch Agent to send logs and metrics"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        "Action" : [
          "cloudwatch:PutMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ssm:GetParameter",
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_cloudwatch_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}


resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "CloudWatchAgentInstanceProfile"
  role = aws_iam_role.cloudwatch_agent_role.name
}
