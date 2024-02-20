#GitLab CI
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "vault_aws_access_credentials" "creds" {
  backend = "aws"
  role    = "aws-role"
  type = "sts"
}

provider "aws" {
  region = var.vpc_vars.region
  default_tags {
    tags = {
      Environment = "dev"
      Application = "web"
    }
  }
  skip_credentials_validation = true
  token = data.vault_aws_access_credentials.creds.security_token
  access_key                  = data.vault_aws_access_credentials.creds.access_key
  secret_key                  = data.vault_aws_access_credentials.creds.secret_key
}

#Create the VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_vars.cidr
  enable_dns_hostnames = true
}

# Define the public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.vpc_vars.subnet
  availability_zone = var.vpc_vars.az
}

# Define the internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

# Define the public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.vpc_vars.rt_cidr
    gateway_id = aws_internet_gateway.gw.id
  }
}
# Assign the public route table to the public subnet
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "allow_ports" {
  name   = "gitlabci-sg"
  vpc_id = aws_vpc.vpc.id
  dynamic "ingress" {
    for_each = var.rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.proto
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nodes" {
  for_each      = var.instances
  instance_type = each.value.instance_type
  ami           = each.value.ami
  key_name      = each.value.key_name

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_ports.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
sudo yum install pip -y
pip install hvac
EOF

  tags = {
    Name        = each.key
    Application = each.value.env
  }
}