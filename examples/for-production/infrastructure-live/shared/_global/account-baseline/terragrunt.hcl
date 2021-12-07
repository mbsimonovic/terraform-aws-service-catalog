# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/landingzone/account-baseline-app-base.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}


# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  common_vars    = include.envcommon.locals.common_vars
  accounts       = local.common_vars.locals.accounts
  account_ids    = include.envcommon.locals.account_ids
  aws_region     = include.envcommon.locals.aws_region
  opt_in_regions = include.envcommon.locals.opt_in_regions
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {

  ################################
  # Parameters for AWS Config
  ################################
  # This account sends logs to the Logs account.
  config_aggregate_config_data_in_external_account = true

  # The ID of the Logs account.
  config_central_account_id = local.account_ids.logs




  ##################################
  # KMS keys
  ##################################

  kms_customer_master_keys = {
    # The `shared-secrets` key is used to encrypt AWS Secrets Manager secrets that are shared with other accounts.
    shared-secrets = {
      region                     = local.aws_region
      cmk_administrator_iam_arns = ["arn:aws:iam::${local.account_ids.shared}:root"]
      cmk_user_iam_arns = [{
        name       = ["arn:aws:iam::${local.account_ids.shared}:root"]
        conditions = []
      }]
      cmk_external_user_iam_arns = [
        for name, id in local.account_ids :
        "arn:aws:iam::${id}:root" if name != "shared"
      ]
    }

    # The `ami-encryption` key is used to encrypt AMIs that are shared with other accounts.
    ami-encryption = {
      region                     = local.aws_region
      cmk_administrator_iam_arns = ["arn:aws:iam::${local.account_ids.shared}:root"]
      cmk_user_iam_arns = [{
        name = [
          "arn:aws:iam::${local.account_ids.shared}:root",

          # The autoscaling service-linked role uses this key when invoking AutoScaling actions
          # (e.g. for adding and removing instances in autoscaling groups).
          "arn:aws:iam::${local.account_ids.shared}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
        ]
        conditions = []
      }]
      cmk_external_user_iam_arns = [
        for name, id in local.account_ids :
        "arn:aws:iam::${id}:root" if name != "shared"
      ]
    }
  }

  # Set the default EBS key to be the AMI encryption key.
  ebs_use_existing_kms_keys = true
  ebs_kms_key_name          = "ami-encryption"
  ebs_opt_in_regions        = [local.aws_region]
}