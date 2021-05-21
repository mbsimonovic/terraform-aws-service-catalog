# Common variables for this region
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  aws_region   = "us-west-2"
  state_bucket = "${local.common_vars.locals.name_prefix}-${local.account_vars.locals.account_name}-${local.aws_region}-tf-state"
}
