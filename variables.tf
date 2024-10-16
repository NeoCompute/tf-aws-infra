variable "region" {
  description = "The AWS region to deploy resources"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "aws_profile" {
  description = "The AWS profile to use for deployment"
}

variable "custom_ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "application_port" {
  description = "Port on which your application runs"
  type        = number
}

variable "instance_type" {
  description = "Type of EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 25
}

variable "key_name" {
  description = "SSH key pair to access EC2"
  type        = string
  default     = ""
}
