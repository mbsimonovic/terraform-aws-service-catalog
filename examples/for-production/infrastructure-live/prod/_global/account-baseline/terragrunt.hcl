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
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=master"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Locals are named constants that are reusable within the configuration.
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  security_account_id  = local.common_vars.locals.account_ids["security"]
  security_account_arn = "arn:aws:iam::${local.security_account_id}:root"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # Send CloudTrail logs to this bucket in the security account
  cloudtrail_s3_bucket_name                 = local.common_vars.locals.cloudtrail_s3_bucket_name
  cloudtrail_kms_key_administrator_iam_arns = []

  # Allow access from other AWS accounts
  allow_read_only_access_from_other_account_arns = [local.security_account_arn]
  allow_full_access_from_other_account_arns      = [local.security_account_arn]
}
