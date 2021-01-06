# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP SECURITY BASELINE FOR AWS ORGANIZATION ROOT ACCOUNT
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

module "root_baseline" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-root?ref=v1.0.0"
  source = "../../../../modules/landingzone/account-baseline-root"

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  name_prefix    = var.name_prefix

  # If you're running the example against an account that doesn't have AWS Organization created, change the following value to true
  create_organization = var.create_organization

  # The child accounts to create
  child_accounts = var.child_accounts

  # IAM users to create in this account
  users = var.users

  # These are variables you only need to set at test time so that everything can be deleted cleanly. You will likely
  # NOT need to set this in any real environments.
  force_destroy_users      = var.force_destroy
  cloudtrail_force_destroy = var.force_destroy
  config_force_destroy     = var.force_destroy

  # Enable IAM Access Analyzer
  iam_access_analyzer_type   = var.iam_access_analyzer_type
  iam_access_analyzer_name   = var.iam_access_analyzer_name
  enable_iam_access_analyzer = var.enable_iam_access_analyzer
}

data "aws_caller_identity" "current" {}
