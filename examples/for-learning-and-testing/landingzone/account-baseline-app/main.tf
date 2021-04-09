# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR APP ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.14.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.14.x code.
  required_version = ">= 0.12.26"
}


# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# CALL THE BASELINE MODULE
# ---------------------------------------------------------------------------------------------------------------------

module "app_baseline" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-app"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_support_access_from_other_account_arns   = var.allow_support_access_from_other_account_arns
  allow_logs_access_from_other_account_arns      = var.allow_logs_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns
  allow_auto_deploy_from_other_account_arns      = var.allow_auto_deploy_from_other_account_arns

  auto_deploy_permissions = var.auto_deploy_permissions
  dev_permitted_services  = var.dev_permitted_services

  # We assume the S3 bucket for AWS Config has already been created by account-baseline-root
  config_should_create_s3_bucket                   = false
  config_s3_bucket_name                            = var.config_s3_bucket_name
  config_sns_topic_name                            = var.config_sns_topic_name
  config_should_create_sns_topic                   = var.config_should_create_sns_topic
  config_central_account_id                        = var.config_central_account_id
  config_aggregate_config_data_in_external_account = var.config_aggregate_config_data_in_external_account

  # We assume the S3 bucket and KMS key for CloudTrail have already been created by account-baseline-root
  cloudtrail_s3_bucket_already_exists = true
  cloudtrail_s3_bucket_name           = var.cloudtrail_s3_bucket_name
  cloudtrail_kms_key_arn              = var.cloudtrail_kms_key_arn

  # Create a single global CMK for general use in the account
  kms_customer_master_keys = var.kms_customer_master_keys

  # These are variables you only need to set at test time so that everything can be deleted cleanly. You will likely
  # NOT need to set this in any real environments.
  cloudtrail_force_destroy = var.force_destroy
  config_force_destroy     = var.force_destroy
}

data "aws_caller_identity" "current" {}