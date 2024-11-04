output "vpc_id" {
  value = aws_vpc.vpc-01.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.ig-01.id
}

output "public_route_table_id" {
  value = aws_route_table.public_route_table.id
}

output "private_route_table_id" {
  value = aws_route_table.private_route_table.id
}

# output "instance_public_ip" {
#   value = aws_instance.webapp-instance.public_ip
# }

output "application_port" {
  value = var.application_port
}

output "db_instance_endpoint" {
  value = aws_db_instance.rds_instance.endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}
