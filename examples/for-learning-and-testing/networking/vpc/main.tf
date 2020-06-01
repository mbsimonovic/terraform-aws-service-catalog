# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN APP VPC, WITH THREE SUBNET TIERS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "../../../../modules/networking/vpc"

  aws_region       = var.aws_region
  cidr_block       = var.cidr_block
  num_nat_gateways = var.num_nat_gateways
  vpc_name         = var.vpc_name

  // Providing an existing key avoids to create a new one every run,
  // this is good to avoid since each costs $1/month
  kms_key_arn = data.aws_kms_key.kms_key.arn
}

resource "aws_security_group" "example" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = element(module.vpc.public_subnet_ids, 0)
  vpc_security_group_ids      = [aws_security_group.example.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
}
