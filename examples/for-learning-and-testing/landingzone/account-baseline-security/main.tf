# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR SECURITY ACCOUNT
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
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-security?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-security"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  # Create a single global CMK for general use in the account
  kms_customer_master_keys = {
    account-default-cmk = {
      region                                = var.aws_region
      cmk_administrator_iam_arns            = ["arn:aws:iam::123456789012:user/acme-admin"]
      cmk_user_iam_arns                     = []
      cmk_external_user_iam_arns            = []
      allow_manage_key_permissions_with_iam = false
    }
  }
}

data "aws_caller_identity" "current" {}
