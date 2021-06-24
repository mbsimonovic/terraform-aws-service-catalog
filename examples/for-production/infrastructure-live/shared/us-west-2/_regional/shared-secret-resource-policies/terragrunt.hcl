# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/secrets-manager-resource-policies?ref=v0.49.4"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}




# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name for easy access
  account_name = local.account_vars.locals.account_name

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region
  # A local for more convenient access to the accounts map.
  accounts          = local.common_vars.locals.accounts
  accounts_to_share = [for name, id in local.accounts : "arn:aws:iam::${id}:root" if name != "shared"]
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  secret_policies = {
    GitHubPAT = {
      arn                           = ""
      iam_entities_with_read_access = local.accounts_to_share
      iam_entities_with_full_access = []
      policy_statement_json         = ""
    },
    SSHPrivateKey = {
      arn                           = "arn:aws:secretsmanager:us-west-2:234567890123:secret:GitSSHPrivateKey"
      iam_entities_with_read_access = local.accounts_to_share
      iam_entities_with_full_access = []
      policy_statement_json         = ""
    },
    VCSPAT = {
      arn                           = "arn:aws:secretsmanager:us-west-2:234567890123:secret:MachineUserGitHubPAT-abcdef"
      iam_entities_with_read_access = local.accounts_to_share
      iam_entities_with_full_access = []
      policy_statement_json         = ""
    },
  }
}