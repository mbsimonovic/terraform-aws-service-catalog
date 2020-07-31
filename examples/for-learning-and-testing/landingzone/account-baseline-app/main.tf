# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR APP ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-app"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_logs_access_from_other_account_arns      = var.allow_logs_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns
  allow_auto_deploy_from_other_account_arns      = var.allow_auto_deploy_from_other_account_arns

  auto_deploy_permissions = var.auto_deploy_permissions
  dev_permitted_services  = var.dev_permitted_services

  config_s3_bucket_name          = var.config_s3_bucket_name
  config_should_create_s3_bucket = var.config_should_create_s3_bucket
  config_linked_accounts         = var.config_linked_accounts

  cloudtrail_kms_key_arn                = var.cloudtrail_kms_key_arn
  cloudtrail_s3_bucket_already_exists   = var.cloudtrail_s3_bucket_already_exists
  cloudtrail_s3_bucket_name             = var.cloudtrail_s3_bucket_name
  cloudtrail_cloudwatch_logs_group_name = var.cloudtrail_cloudwatch_logs_group_name

  # If this is the account that creates the KMS CMK for encrypting CloudTrail logs (e.g., if this is the logs account), you must grant at least one administrator and user access to the CMK in order to deploy successfully
  cloudtrail_kms_key_administrator_iam_arns = var.cloudtrail_kms_key_administrator_iam_arns
  cloudtrail_kms_key_user_iam_arns          = var.cloudtrail_kms_key_user_iam_arns

  # If this is the account that is used to aggregate CloudTrail logs (e.g., this is the logs account), specify the external accounts (e.g., dev, stage, prod) that should have permissions to write their logs to this account
  cloudtrail_external_aws_account_ids_with_write_access = var.cloudtrail_external_aws_account_ids_with_write_access

  # Create a single global CMK for general use in the account
  kms_customer_master_keys = var.kms_customer_master_keys
}


data "aws_caller_identity" "current" {}
