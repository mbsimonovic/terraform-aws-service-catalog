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

module "security_baseline" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-app?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-app"

  aws_account_id = data.aws_caller_identity.current.id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  allow_read_only_access_from_other_account_arns = var.allow_read_only_access_from_other_account_arns
  allow_billing_access_from_other_account_arns   = var.allow_billing_access_from_other_account_arns
  allow_ssh_grunt_access_from_other_account_arns = var.allow_ssh_grunt_access_from_other_account_arns
  allow_dev_access_from_other_account_arns       = var.allow_dev_access_from_other_account_arns
  allow_full_access_from_other_account_arns      = var.allow_full_access_from_other_account_arns
  allow_auto_deploy_from_other_account_arns      = var.allow_auto_deploy_from_other_account_arns

  auto_deploy_permissions = var.auto_deploy_permissions
  dev_permitted_services  = var.dev_permitted_services

  cloudtrail_kms_key_administrator_iam_arns = var.cloudtrail_kms_key_administrator_iam_arns
  cloudtrail_s3_bucket_name                 = var.cloudtrail_s3_bucket_name
}

data "aws_caller_identity" "current" {}
