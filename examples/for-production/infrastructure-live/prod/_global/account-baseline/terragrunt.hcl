terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=v0.0.1"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  security_account_arn = "arn:aws:iam::${local.account_vars.inputs.security_account_id}:root"
}

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # Allow access from other AWS accounts
  allow_read_only_access_from_other_account_arns = [local.security_account_arn]
  allow_full_access_from_other_account_arns      = [local.security_account_arn]
}