terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=master"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))
}

dependencies {
  paths = ["../../../../_global/account-baseline"]
}

inputs = {
  vpc_name         = "prod-vpc"
  cidr_block       = local.account_vars.locals.prod_cidr_block
  num_nat_gateways = 3
  create_flow_logs = false
}