terraform {
  source = "../../../../../../../../modules/mock-vpc"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  vpc_name = "prod-vpc"
}