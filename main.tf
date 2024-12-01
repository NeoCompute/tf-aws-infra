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

resource "aws_security_group" "application-security-group" {
  vpc_id = aws_vpc.vpc-01.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = var.application_port
    to_port         = var.application_port
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
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
  }

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
  password               = random_password.db_password.result
  parameter_group_name   = aws_db_parameter_group.postgresql_parameter_group.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.database-security-group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name # Using DB Subnet Group
  multi_az               = false
  kms_key_id             = aws_kms_key.kms_rds_key.arn
  storage_encrypted      = true

  tags = {
    Name = "csye6225"
  }
  depends_on = [random_password.db_password]
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

# resource "aws_kms_key" "kms_key" {
#   description             = "This key is used to encrypt bucket objects"
#   deletion_window_in_days = 10
# }

resource "aws_s3_bucket" "bucket" {
  bucket        = random_uuid.bucket_name.result
  force_destroy = true
} // Creating S3 bucket with random UUID

resource "aws_s3_bucket_server_side_encryption_configuration" "aws_s3_server_side_config" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.kms_s3_key.arn
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

resource "aws_route53_record" "app_alias_record" {
  zone_id = var.hosted_zone_id
  name    = var.subdomain_name
  type    = "A"

  alias {
    name                   = aws_lb.app_load_balancer.dns_name
    zone_id                = aws_lb.app_load_balancer.zone_id
    evaluate_target_health = true
  }
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
          "ec2:DescribeVolumes",
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "s3:PutObject",
          "s3:DeleteObject",
          "sns:Publish",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      },
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


# Load Balancer Security Group
resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.vpc-01.id

  # Ingress rule to allow HTTP (port 80) from any IP
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow HTTP traffic from any IP"
  }

  # Ingress rule to allow HTTPS (port 443) from any IP
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow HTTPS traffic from any IP"
  }

  # Egress rule to allow all outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow all outbound traffic"
  }

  tags = {
    Name = "load-balancer-security-group"
  }
}


resource "aws_launch_template" "csye6225_asg" {
  name_prefix = "webapp-launch-template-"

  image_id      = var.custom_ami
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.cloudwatch_agent_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.public_subnets[0].id
    security_groups             = [aws_security_group.application-security-group.id]
  }

  user_data = base64encode(templatefile("./scripts/user_data_script.sh", {
    DB_HOST               = substr(aws_db_instance.rds_instance.endpoint, 0, length(aws_db_instance.rds_instance.endpoint) - 5)
    DB_USER               = var.db_username
    DB_NAME               = var.database_name
    APP_PORT              = var.application_port
    ENVIRONMENT           = var.webapp_environment
    S3_BUCKET_NAME        = aws_s3_bucket.bucket.bucket
    SNS_TOPIC_ARN         = aws_sns_topic.user_verification_topic.arn
    TOKEN_EXPIRATION_TIME = var.token_expiry_time
    RDS_SECRET_NAME       = aws_secretsmanager_secret.rds_secret.name
  }))

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webapp-ec2-instance"
    }
  }
  depends_on = [aws_secretsmanager_secret.rds_secret]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 3
  max_size            = 5
  min_size            = 3
  default_cooldown    = 60
  vpc_zone_identifier = aws_subnet.public_subnets[*].id

  launch_template {
    id      = aws_launch_template.csye6225_asg.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_target_group.arn]

  tag {
    key                 = "Name"
    value               = "webapp-ec2-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# CloudWatch Alarm for Scaling Up
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 10
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

# CloudWatch Alarm for Scaling Down
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 7
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}


# Application Load Balancer
resource "aws_lb" "app_load_balancer" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_security_group.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  tags = {
    Name = "app-load-balancer"
  }
}

# Target Group for the Application
resource "aws_lb_target_group" "app_target_group" {
  name        = "app-target-group"
  port        = var.application_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-01.id
  target_type = "instance"

  health_check {
    path                = "/healthz"
    interval            = 120
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "app-target-group"
  }
}

# ALB Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

# Create a SNS Topic
resource "aws_sns_topic" "user_verification_topic" {
  name = "user-verification-topic"
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# IAM Policy for Lambda Permissions
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-sns-policy"
  description = "Permissions for Lambda to access SNS and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : ["sns:Publish"],
        Resource : aws_sns_topic.user_verification_topic.arn
      },
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "arn:aws:logs:*:*:*"
      },
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ], Resource : aws_secretsmanager_secret.email_service_secret.arn
      },
      {
        Effect   = "Allow",
        Action   = ["kms:Decrypt"],
        Resource = aws_kms_key.kms_secrets_manager_key.arn
      }
    ]
  })
}

# Attach the policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}


resource "aws_lambda_function" "user_verification_lambda" {
  filename      = var.lambda_function_path
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = 128
  timeout       = 30

  environment {
    variables = {
      EMAIL_SECRET_ARN = aws_secretsmanager_secret.email_service_secret.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_log_group,
    aws_secretsmanager_secret.email_service_secret,
    aws_secretsmanager_secret_version.email_service_secret_value
  ]
}

resource "aws_sns_topic_subscription" "lambda_sns_subscription" {
  topic_arn = aws_sns_topic.user_verification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.user_verification_lambda.arn

  depends_on = [
    aws_lambda_function.user_verification_lambda
  ]
}

resource "aws_lambda_permission" "allow_sns_invocation" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_verification_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_verification_topic.arn
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
  tags = {
    Name = "${var.lambda_function_name}-log-group"
  }
}

resource "aws_cloudwatch_log_stream" "lambda_log_stream" {
  name           = "${var.lambda_function_name}-stream"
  log_group_name = aws_cloudwatch_log_group.lambda_log_group.name
}

# KMS Key for RDS
resource "aws_kms_key" "kms_rds_key" {
  description             = "This key is used to encrypt RDS instances"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = {
    Name = "kms-key-rds"
  }
}

# KMS Key for S3 buckets
resource "aws_kms_key" "kms_s3_key" {
  description             = "This key is used to encrypt S3 buckets"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = {
    Name = "kms-key-s3"
  }
}

# KMS Key for Secrets Manager
resource "aws_kms_key" "kms_secrets_manager_key" {
  description             = "KMS Key for secret manager"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = {
    Name = "kms-key-secrets-manager"
  }
}

resource "random_pet" "secrets_suffix" {
  length = 2
}

resource "aws_secretsmanager_secret" "rds_secret" {
  name        = "rds-database-password-${random_pet.secrets_suffix.id}"
  kms_key_id  = aws_kms_key.kms_secrets_manager_key.arn
  description = "Database password for RDS"

  tags = {
    Name = "rds-secret-${random_pet.secrets_suffix.id}"
  }
}

resource "aws_secretsmanager_secret" "email_service_secret" {
  name        = "email-service-credentials-${random_pet.secrets_suffix.id}"
  kms_key_id  = aws_kms_key.kms_secrets_manager_key.arn
  description = "Email service credentials for Lambda function"

  tags = {
    Name = "email-service-credentials-${random_pet.secrets_suffix.id}"
  }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&'()*+,-.:;<=>?[]^_{|}~"
}

resource "aws_secretsmanager_secret_version" "rds_secret_value" {
  secret_id = aws_secretsmanager_secret.rds_secret.id
  secret_string = jsonencode({
    password = random_password.db_password.result
  })
}
resource "aws_secretsmanager_secret_version" "email_service_secret_value" {
  secret_id = aws_secretsmanager_secret.email_service_secret.id
  secret_string = jsonencode({
    apiKey                   = var.mailgun_api_key,
    domain                   = var.mailgun_domain,
    fromEmail                = var.from_email,
    verify_email_link        = var.verify_email_link,
    verify_email_expiry_time = var.verify_email_expiry_time
  })
}
