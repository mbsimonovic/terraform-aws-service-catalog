terraform {
  source = "../../../../../../infrastructure-modules//services/custom-asg-service"
}

dependency "vpc" {
  config_path = "../../networking/mock-vpc"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  vpc_id   = dependency.vpc.outputs.vpc_id
  ami_id   = "ami-abcd1234"
  key_name = "jim-brikman"
}