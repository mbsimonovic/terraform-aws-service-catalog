terraform {
  source = "../../../modules/mock-vpc"
}

inputs = {
  vpc_name = "vpc-foo"
}