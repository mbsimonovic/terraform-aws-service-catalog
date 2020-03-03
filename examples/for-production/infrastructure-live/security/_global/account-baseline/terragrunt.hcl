terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-security?ref=landing-zone-v1"
}

include {
  path = find_in_parent_folders()
}

locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  security_full_access_group_name = "full-access"
  access_all_accounts_group_name  = "access-all-external-accounts"
  stage_full_access_group_name    = "_account.stage-full-access"
  stage_read_only_group_name      = "_account.stage-read-only"
  prod_full_access_group_name     = "_account.prod-full-access"
  prod_read_only_group_name       = "_account.prod-read-only"
  ssh_grunt_sudo_group_name       = "ssh-grunt-sudo-users"
}

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # Send CloudTrail logs to this bucket
  cloudtrail_s3_bucket_name = local.common_vars.locals.cloudtrail_s3_bucket_name

  # This IAM group gives access to other AWS accounts
  iam_groups_for_cross_account_access = [
    {
      group_name   = local.stage_full_access_group_name
      iam_role_arn = "arn:aws:iam::${local.common_vars.locals.account_ids["stage"]}:role/allow-full-access-from-other-accounts"
    },
    {
      group_name   = local.stage_read_only_group_name
      iam_role_arn = "arn:aws:iam::${local.common_vars.locals.account_ids["stage"]}:role/allow-read-only-access-from-other-accounts"
    },
    {
      group_name   = local.prod_full_access_group_name
      iam_role_arn = "arn:aws:iam::${local.common_vars.locals.account_ids["prod"]}:role/allow-full-access-from-other-accounts"
    },
    {
      group_name   = local.prod_read_only_group_name
      iam_role_arn = "arn:aws:iam::${local.common_vars.locals.account_ids["prod"]}:role/allow-read-only-access-from-other-accounts"
    },
  ]

  # The IAM users to create in this account. Since this is the security account, this is where we create all of our
  # IAM users and add them to IAM groups.
  users = {
    alice = {
      groups               = [local.security_full_access_group_name, local.access_all_accounts_group_name, local.ssh_grunt_sudo_group_name]
      pgp_key              = "keybase:alice_on_keybase"
      create_login_profile = true
      create_access_keys   = false
    }

    bob = {
      groups               = [local.stage_full_access_group_name, local.prod_read_only_group_name, local.ssh_grunt_sudo_group_name]
      pgp_key              = "keybase:bob_on_keybase"
      create_login_profile = true
      create_access_keys   = false
    }

    carol = {
      groups               = [local.stage_full_access_group_name]
      pgp_key              = "keybase:carol_on_keybase"
      create_login_profile = true
      create_access_keys   = false
    }
  }
}