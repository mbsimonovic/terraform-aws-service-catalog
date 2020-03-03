terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/vpc-app?ref=master"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

dependencies {
  paths = ["../../../../_global/account-baseline"]
}

inputs = {
  vpc_name         = "${local.account_vars.locals.account_name}-vpc"
  cidr_block       = local.common_vars.locals.vpc_cidr_blocks[local.account_vars.locals.account_name]
  num_nat_gateways = 1
  create_flow_logs = false
}