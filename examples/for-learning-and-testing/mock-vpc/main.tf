provider "aws" {
  region = var.aws_region
}

module "mock_vpc" {
  source = "../../../modules/mock-vpc"

  vpc_name = var.vpc_name
}

