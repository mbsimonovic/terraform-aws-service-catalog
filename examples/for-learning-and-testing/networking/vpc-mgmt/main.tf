# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY A MANAGEMENT VPC, WITH TWO SUBNET TIERS
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"
}


provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "../../../../modules/networking/vpc-mgmt"

  vpc_name         = var.vpc_name
  aws_region       = var.aws_region
  cidr_block       = var.cidr_block
  num_nat_gateways = var.num_nat_gateways
  create_flow_logs = var.create_flow_logs

  # Providing an existing key avoids creating a new one every run.
  # This is good to avoid since each costs $1/month.
  kms_key_arn = data.aws_kms_key.kms_key.arn
}

# ----------------------------------------------------------------------------------------------------------------------
# Deploy an instance with a security group to this VPC for testing purposes
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "example" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = var.sg_ingress_port
    to_port   = var.sg_ingress_port
    protocol  = "tcp"

    # To simplify testing and for example purposes, we allow access to the instance from anywhere.
    # In production, you'll want to limit access to trusted systems only 
    # (e.g., solely a bastion host or VPN server).
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = module.instance_types.recommended_instance_type
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  vpc_security_group_ids      = [aws_security_group.example.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.sg_ingress_port} &
              EOF
}
