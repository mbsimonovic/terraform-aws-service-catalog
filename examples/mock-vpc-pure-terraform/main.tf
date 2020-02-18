provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "local" {
    path = "foo.tfstate"
  }
}

module "vpc" {
  source = "../../modules/mock-vpc"

  vpc_name = "foo"
}
