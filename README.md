# tf-aws-infra

My IaaC using Terraform for AWS Cloud Platform for CYSE6225 Network Structures and Cloud Computing

### Networking Setup
- VPC Network
- Subnet:
   - /16 CIDR range
- Attached Internet Gateway to the VPC for allowing incoming requests



## How to build & run the application

1. Add your variables in ./terraform.tfvars

```
region = 
vpc_cidr = 
public_subnet_cidrs = 
private_subnet_cidrs = 
availability_zones = 
aws_profile = 

custom_ami =
key_name =
instance_type =
root_volume_size =

application_port = 

db_password =
db_username =
database_name =
```

2. Terraform Initalization
   
```
terraform init
```

3. Terraform Validate
   
```
terraform validate
```

4. Terraform Apply
   
```
terraform apply
```

5. Command to import the SSL Certificates

```
aws acm import-certificate \
  --certificate file://<path> \
  --certificate-chain file://<path> \
  --private-key file://<path> \
  --region us-east-1 \
  --profile demo
```

## References:
1. [Install Brew](https://brew.sh/)
2. [Install Terraform using Brew](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
3. [Install aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
4. [Set up Terraform](https://developer.hashicorp.com/terraform/install?ajs_aid=ee087ad3-951d-4cf7-bcf4-ebbe422dd887&product_intent=terraform)
