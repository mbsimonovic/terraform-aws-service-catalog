provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "local" {
    path = "foo.tfstate"
  }
}

module "asg_service" {
  source = "../../modules/mock-asg-service"

  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  ami_id = "ami-abcd1234"

  cloud_init_parts = {
    foo = {
      content_type = "text/x-shellscript"
      content      = <<EOF
#!/usr/bin/env bash
echo 'Hello, World custom!' > /home/ubuntu/test-custom.txt
EOF
    }
  }

  key_name = "jim-brikman"
}

data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../mock-vpc/foo.tfstate"
  }
}