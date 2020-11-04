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
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-security?ref=v1.0.8"
  source = "../../../../../../modules//landingzone/account-baseline-security"

  # This module deploys some resources (e.g., AWS Config) across all AWS regions, each of which needs its own provider,
  # which in Terraform means a separate process. To avoid all these processes thrashing the CPU, which leads to network
  # connectivity issues, we limit the parallelism here.
  extra_arguments "parallelism" {
    commands  = get_terraform_commands_that_need_parallelism()
    arguments = ["-parallelism=2"]
  }
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Locals are named constants that are reusable within the configuration.
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  security_full_access_group_name        = "full-access"
  access_all_accounts_group_name         = "access-all-external-accounts"
  stage_full_access_group_name           = "_account.stage-full-access"
  stage_read_only_group_name             = "_account.stage-read-only"
  prod_full_access_group_name            = "_account.prod-full-access"
  prod_read_only_group_name              = "_account.prod-read-only"
  ssh_grunt_sudo_group_name              = "ssh-grunt-sudo-users"
  ssh_grunt_user_group_name              = "ssh-grunt-users"
  bastion_only_ssh_grunt_user_group_name = "bastion-only-ssh-grunt-users"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # Send CloudTrail logs to this bucket
  cloudtrail_s3_bucket_name = local.common_vars.locals.cloudtrail_s3_bucket_name

  # This IAM group gives access to other AWS accounts
  iam_groups_for_cross_account_access = [
    {
      group_name    = local.stage_full_access_group_name
      iam_role_arns = ["arn:aws:iam::${local.common_vars.locals.account_ids["stage"]}:role/allow-full-access-from-other-accounts"]
    },
    {
      group_name    = local.stage_read_only_group_name
      iam_role_arns = ["arn:aws:iam::${local.common_vars.locals.account_ids["stage"]}:role/allow-read-only-access-from-other-accounts"]
    },
    {
      group_name    = local.prod_full_access_group_name
      iam_role_arns = ["arn:aws:iam::${local.common_vars.locals.account_ids["prod"]}:role/allow-full-access-from-other-accounts"]
    },
    {
      group_name    = local.prod_read_only_group_name
      iam_role_arns = ["arn:aws:iam::${local.common_vars.locals.account_ids["prod"]}:role/allow-read-only-access-from-other-accounts"]
    },
  ]
  cross_account_access_all_group_name  = local.access_all_accounts_group_name
  iam_group_names_ssh_grunt_sudo_users = [local.ssh_grunt_sudo_group_name]
  iam_group_names_ssh_grunt_users = [
    local.ssh_grunt_user_group_name,
    local.bastion_only_ssh_grunt_user_group_name,
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
