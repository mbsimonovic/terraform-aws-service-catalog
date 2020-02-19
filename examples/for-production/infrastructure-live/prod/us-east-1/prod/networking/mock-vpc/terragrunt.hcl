terraform {
  source = "../../../../../../../../modules/networking/mock-vpc"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  vpc_name = "prod-vpc"
}