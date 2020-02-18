resource "random_pet" "example" {
  keepers = {
    amm_id = var.ami_id
    vpc_id = var.vpc_id
  }

  prefix = "ami-"
}

locals {
  # Default cloud init script for this module
  cloud_init = {
    content_type = "text/x-shellscript"
    content      = <<EOF
#!/usr/bin/env bash
echo 'Hello, World!' > /home/ubuntu/test-default.txt
EOF
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)
}

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  dynamic "part" {
    for_each = local.cloud_init_parts

    content {
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  user_data_base64       = data.template_cloudinit_config.cloud_init.rendered
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.instance.id]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}

resource "aws_security_group" "instance" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}