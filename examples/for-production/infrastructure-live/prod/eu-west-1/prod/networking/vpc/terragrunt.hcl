terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=v0.0.1"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
}

inputs = {
  vpc_name         = "prod-vpc"
  cidr_block       = local.account_vars.inputs.prod_cidr_block
  num_nat_gateways = 3
}