provider "aws" {
  region = var.aws_region
}

module "vpc_app" {
  source = "../../../../modules/networking/vpc-app"

  aws_region       = var.aws_region
  cidr_block       = var.cidr_block
  num_nat_gateways = var.num_nat_gateways
  vpc_name         = var.vpc_name

  // Providing an Key avoids to create a new one every run,
  // this is good to avoid since each costs $1/month
  kms_key_arn =  data.aws_kms_key.kms_key.arn
}

resource "aws_security_group" "example" {
  vpc_id = module.vpc_app.vpc_id
  ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }

}

resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id = element(module.vpc_app.public_subnet_ids, 0)
  vpc_security_group_ids = [aws_security_group.example.id]
  associate_public_ip_address = true
}
