# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name_prefix" {
  description = "The name used to prefix AWS Config and Cloudtrail resources, including the S3 bucket names and SNS topics used for each."
  type        = string
}

variable "aws_region" {
  description = "The AWS Region to use as the global config recorder and seed region for AWS GuardDuty."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS Account ID the template should be operated on. This avoids misconfiguration errors caused by environment variables."
  type        = string
}

variable "child_accounts" {
  description = "Map of child accounts to create. The map key is the name of the account and the value is an object containing account configuration variables. See the comments below for what keys and values this object should contain."

  # Ideally, this would be a map of (string, object), but object does not support optional properties, and we want
  # users to be able to specify, say, tags for some accounts, but not for others. We can't use a map(any) either, as that
  # would require the values to all have the same type, and due to optional parameters, that wouldn't work either. So,
  # we have to lamely fall back to any.
  type = any

  # Expected value for the `child_accounts` is a map of child accounts. The map key is the name of the account and
  # the value is another map with one required key (email) and several optional keys:
  #
  # - email (required):
  #   Email address for the account.
  #
  # - is_logs_account:
  #   Set to `true` to mark this account as the "logs" account, which is the one to use to aggregate AWS Config and
  #   CloudTrail data. This module will create an S3 bucket for AWS Config and an S3 bucket and KMS CMK for CloudTrail
  #   in this child account, configure the root account to send all its AWS Config and CloudTrail data there, and return
  #   the names of the buckets and ARN of the KMS CMK as output variables. When you apply account baselines to the
  #   other child accounts (e.g., using the account-baseline-app or account-baseline-security modules), you'll want to
  #   configure those accounts to send AWS Config and CloudTrail data to the same S3 buckets and use the same KMS CMK.
  #   If is_logs_account is not set on any child account (not recommended!), then either you must disable AWS Config
  #   and CloudTrail (via the enable_config and enable_cloudtrail variables) or configure this module to use S3 buckets
  #   and a KMS CMK that ALREADY exist!
  #
  # - parent_id:
  #   Parent Organizational Unit ID or Root ID for the account
  #   Defaults to the Organization default Root ID.
  #
  # - role_name:
  #   The name of an IAM role that Organizations automatically preconfigures in the new member account. This role trusts
  #   the master account, allowing users in the master account to assume the role, as permitted by the master account
  #   administrator. The role has administrator permissions in the new member account. Note that the Organizations API
  #   provides no method for reading this information after account creation.
  #   If no value is present and no ??default_role_name?? is provided, AWS automatically assigns a value.
  #
  # - iam_user_access_to_billing:
  #   If set to ??ALLOW??, the new account enables IAM users to access account billing information if they have the required
  #   permissions. If set to ??DENY??, then only the root user of the new account can access account billing information.
  #   Defaults to ??default_iam_user_access_to_billing??.
  #
  #
  # - enable_config_rules:
  #   Set to `true` to enable org-level AWS Config Rules for this child account. This is only used if
  #   var.config_create_account_rules is false (which is NOT recommened) to force org-level rules. If you do go with
  #   org-level rules, you can only set enable_config_rules to true after deploying a Config Recorder in the child
  #   account. That means you have to: (1) initially set enable_config_rules to false, (2) run 'apply' in this root
  #   module to create the child account, (3) go to the child account and create a config recorder in it, e.g., by
  #   running 'apply' on a security baseline in that account, (4) come back to this root module and set
  #   enable_config_rules to true, (5) run 'apply' again. This is a brittle, error-prone, multi-step process, which is
  #   why we recommend using account-level rules (the default) and avoiding it entirely!
  #
  # - tags:
  #   Key-value mapping of resource tags.
  #
  #
  # Example:
  #
  # child_accounts = {
  #   logs = {
  #     email                       = "root-accounts+logs@acme.com"
  #     is_logs_account             = true
  #   }
  #   security = {
  #     email                       = "root-accounts+security@acme.com"
  #     role_name                   = "OrganizationAccountAccessRole"
  #     iam_user_access_to_billing  = "DENY"
  #     tags = {
  #       Tag-Key = "tag-value"
  #     }
  #   }
  #   shared-services = {
  #     email                       = "root-accounts+shared-services@acme.com"
  #   }
  #   dev = {
  #     email                       = "root-accounts+dev@acme.com"
  #   }
  #   stage = {
  #     email                       = "root-accounts+stage@acme.com"
  #   }
  #   prod = {
  #     email                       = "root-accounts+prod@acme.com"
  #   }
  # }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "create_organization" {
  description = "Set to true to create/configure AWS Organizations for the first time in this account. If you already configured AWS Organizations in your account, set this to false; alternatively, you could set it to true and run 'terraform import' to import you existing Organization."
  type        = bool
  default     = false
}

variable "users" {
  description = "A map of users to create. The keys are the user names and the values are an object with the optional keys 'groups' (a list of IAM groups to add the user to), 'tags' (a map of tags to apply to the user), 'pgp_key' (either a base-64 encoded PGP public key, or a keybase username in the form keybase:username, used to encrypt the user's credentials; required if create_login_profile or create_access_keys is true), 'create_login_profile' (if set to true, create a password to login to the AWS Web Console), 'create_access_keys' (if set to true, create access keys for the user), 'path' (the path), and 'permissions_boundary' (the ARN of the policy that is used to set the permissions boundary for the user)."

  # Ideally, this would be a map of (string, object), but object does not support optional properties, and we want
  # users to be able to specify, say, tags for some users, but not for others. We can't use a map(any) either, as that
  # would require the values to all have the same type, and due to optional parameters, that wouldn't work either. So,
  # we have to lamely fall back to any.
  type = any

  # Example:
  # default = {
  #   alice = {
  #     groups = ["user-self-mgmt", "developers", "ssh-sudo-users"]
  #   }
  #
  #   bob = {
  #     path   = "/"
  #     groups = ["user-self-mgmt", "ops", "admins"]
  #     tags   = {
  #       foo = "bar"
  #     }
  #   }
  #
  #   carol = {
  #     groups               = ["user-self-mgmt", "developers", "ssh-users"]
  #     pgp_key              = "keybase:carol_on_keybase"
  #     create_login_profile = true
  #     create_access_keys   = true
  #   }
  # }

  default = {}
}

variable "force_destroy" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from all S3 buckets and any IAM users created by this module so that everything can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything! This is mostly useful when testing."
  type        = bool
  default     = false
}

variable "opt_in_regions" {
  description = "Create multi-region resources in the specified regions. The best practice is to enable multi-region services in all enabled regions in your AWS account. This variable must NOT be set to null or empty. Otherwise, we won't know which regions to use and authenticate to, and may use some not enabled in your AWS account (e.g., GovCloud, China, etc). To get the list of regions enabled in your AWS account, you can use the AWS CLI: aws ec2 describe-regions."
  type        = list(string)
  default = [
    "eu-north-1",
    "ap-south-1",
    "eu-west-3",
    "eu-west-2",
    "eu-west-1",
    "ap-northeast-2",
    "ap-northeast-1",
    "sa-east-1",
    "ca-central-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "eu-central-1",
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",

    # By default, skip regions that are not enabled in most AWS accounts:
    #
    #  "af-south-1",     # Cape Town
    #  "ap-east-1",      # Hong Kong
    #  "eu-south-1",     # Milan
    #  "me-south-1",     # Bahrain
    #  "us-gov-east-1",  # GovCloud
    #  "us-gov-west-1",  # GovCloud
    #  "cn-north-1",     # China
    #  "cn-northwest-1", # China
    #
    # This region is enabled by default but is brand-new and some services like AWS Config don't work.
    # "ap-northeast-3", # Asia Pacific (Osaka)
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM ACCESS ANALYZER MODULE EXAMPLE PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_iam_access_analyzer" {
  description = "A feature flag to enable or disable this module."
  type        = bool
  default     = false
}

# This variable sets the type of the IAM Access Analyzer. Depending on the trust zone required for the analyzer to cover,
# the possible values are:
# - ACCOUNT;
# - ORGANIZATION.
# When set to ACCOUNT - the trust zone for the IAM Access Analyzer will be limited to just the account and resources
# only within this account will be scanned, instead of the organizational boundaries and its policies.
# When set to ORGANIZATION - the trust zone will be set to the whole organization, which allows the IAM Access Analyzer
# to scan relevant resources shared and applicable within the bounds of the organization. The AWS account with type of
# IAM Access Analyzer type set to ORGANIZATION, must
# - an AWS organization master account;
# - or be part of an AWS organization & set as a delegated admin for this feature.
#
# For more information, please read here: https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html
variable "iam_access_analyzer_type" {
  description = "If set to ORGANIZATION, the analyzer will be scanning the current organization and any policies that refer to linked resources and their policies within the organization's boundaries."
  type        = string
  default     = "ORGANIZATION"
}

variable "iam_access_analyzer_name" {
  description = "The name of the IAM Access Analyzer module"
  type        = string
  default     = "baseline_root-iam_access_analyzer"
}