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
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/landingzone/account-baseline-security?ref=v0.38.1"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/landingzone/account-baseline-security"

  # This module deploys some resources (e.g., AWS Config) across all AWS regions, each of which needs its own provider,
  # which in Terraform means a separate process. To avoid all these processes thrashing the CPU, which leads to network
  # connectivity issues, we limit the parallelism here.
  extra_arguments "parallelism" {
    commands  = get_terraform_commands_that_need_parallelism()
    arguments = get_env("TG_DISABLE_PARALLELISM_LIMIT", "false") == "true" ? [] : ["-parallelism=2"]
  }
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
  accounts = local.common_vars.locals.accounts

  users = yamldecode(file("users.yml"))
  cross_account_groups = try(
    yamldecode(
      templatefile(
        "cross_account_groups.yml",
        {
          accounts = local.accounts
        },
      ),
    ),
    {},
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  ################################
  # Parameters for AWS Config
  ################################
  # Send Config logs to the common S3 bucket.
  config_s3_bucket_name = local.common_vars.locals.config_s3_bucket_name

  # Send Config logs and events to the logs account.
  config_central_account_id = local.accounts.logs

  # Do not allow objects in the Config S3 bucket to be forcefully removed during destroy operations.
  config_force_destroy = false

  # This account sends logs to the Logs account.
  config_aggregate_config_data_in_external_account = true

  # The ID of the Logs account.
  config_central_account_id = local.accounts.logs

  ################################
  # Parameters for CloudTrail
  ################################

  # Send CloudTrail logs to the common S3 bucket.
  cloudtrail_s3_bucket_name = local.common_vars.locals.cloudtrail_s3_bucket_name

  # The CloudTrail bucket is created in the logs account, so don't create it here.
  cloudtrail_s3_bucket_already_exists = true


  ##################################
  # Cross-account IAM role permissions
  ##################################

  # Create groups that allow IAM users in this account to assume roles in your other AWS accounts.
  iam_groups_for_cross_account_access = local.cross_account_groups.cross_account_groups

  # Allow these accounts to have read access to IAM groups and the public SSH keys of users in the group.
  allow_ssh_grunt_access_from_other_account_arns = [
    for name, id in local.accounts :
    "arn:aws:iam::${id}:root" if name != "security"
  ]

  # A list of account root ARNs that should be able to assume the auto deploy role.
  allow_auto_deploy_from_other_account_arns = [
    # External CI/CD systems may use an IAM user in the security account to perform deployments.
    "arn:aws:iam::${local.accounts.security}:root",

    # The shared account contains automation and infrastructure tools, such as CI/CD systems.
    "arn:aws:iam::${local.accounts.shared}:root",
  ]
  auto_deploy_permissions = [
    "iam:GetRole",
    "iam:GetRolePolicy",
  ]

  # Configures the auto deploy max session duration to be 4 hours
  max_session_duration_machine_users = 14400

  # Configures the max session duration for roles that humans use to be 8 hours
  max_session_duration_human_users = 28800
  # IAM users

  users = local.users
}