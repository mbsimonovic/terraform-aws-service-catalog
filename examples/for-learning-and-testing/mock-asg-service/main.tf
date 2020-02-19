provider "aws" {
  region = var.aws_region
}

module "mock_asg_service" {
  source = "../../../modules/mock-asg-service"

  vpc_id = data.aws_vpc.default.id
  ami_id = "ami-abcd1234"
  port   = 12345
}

