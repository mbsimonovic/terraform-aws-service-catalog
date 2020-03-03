terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=landing-zone-v1"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("accounts.hcl"))

  security_account_arn = "arn:aws:iam::${local.account_vars.locals.security_account_id}:root"
}

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # Send CloudTrail logs to this bucket in the security account
  cloudtrail_s3_bucket_name                 = local.account_vars.locals.cloudtrail_s3_bucket_name
  cloudtrail_kms_key_administrator_iam_arns = []

  # Allow access from other AWS accounts
  allow_read_only_access_from_other_account_arns = [local.security_account_arn]
  allow_full_access_from_other_account_arns      = [local.security_account_arn]
}