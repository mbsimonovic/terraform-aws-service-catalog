terraform {
  source = "../../modules/mock-asg-service"
}

dependency "vpc" {
  config_path = "../mock-vpc"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  ami_id = "ami-abcd1234"
}