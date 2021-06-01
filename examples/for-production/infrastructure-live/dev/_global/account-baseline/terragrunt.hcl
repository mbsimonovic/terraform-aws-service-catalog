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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=v0.36.1"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/landingzone/account-baseline-app"

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

  # A local for convenient access to the security account root ARN.
  security_account_root_arn = "arn:aws:iam::${local.accounts.security}:root"

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



  ##################################
  # Cross-account IAM role permissions
  ##################################

  # By granting access to the root ARN of the Security account in each of the roles below,
  # we allow administrators to further delegate access to other IAM entities

  # A role that allows administrator access to the account.
  allow_full_access_from_other_account_arns = [local.security_account_root_arn]

  # A role for developers to use to access services in the account.
  # Access to services is managed using the dev_permitted_services input.
  allow_dev_access_from_other_account_arns = [local.security_account_root_arn]

  # Assuming the developers role will grant access to these services.
  dev_permitted_services = [
    "ec2",
    "lambda",
    "rds",
    "elasticache",
    "route53",
  ]

  # A role to allow users that can view and modify AWS account billing information.
  allow_billing_access_from_other_account_arns = [local.security_account_root_arn]

  # A role that allows read only access.
  allow_read_only_access_from_other_account_arns = [local.security_account_root_arn]

  # A role that allows access to support only.
  allow_support_access_from_other_account_arns = [local.security_account_root_arn]

  # A list of account root ARNs that should be able to assume the auto deploy role.
  allow_auto_deploy_from_other_account_arns = [
    # External CI/CD systems may use an IAM user in the security account to perform deployments.
    local.security_account_root_arn,

    # The shared account contains automation and infrastructure tools, such as CI/CD systems.
    "arn:aws:iam::${local.accounts.shared}:root",
  ]

  # Assuming the auto-deploy role will grant access to these services.
  auto_deploy_permissions = [
    "iam:GetRole",
    "iam:GetRolePolicy",
  ]

  # Configures the auto deploy max session duration to be 4 hours.
  max_session_duration_machine_users = 14400

  # Configures the max session duration for roles that humans use to be 8 hours.
  max_session_duration_human_users = 28800

  service_linked_roles = ["autoscaling.amazonaws.com"]
}