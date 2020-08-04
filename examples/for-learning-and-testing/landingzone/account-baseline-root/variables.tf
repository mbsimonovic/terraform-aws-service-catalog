# ---------------------------------------------------------------------------------------------------------------------
# EXAMPLE PARAMETERS
# These variables must be passed in by the operator. In a real-world usage, some of these variables might not be needed
# and you can instead inline the values directly in main.tf.
# ---------------------------------------------------------------------------------------------------------------------

variable "name_prefix" {
  description = "The name used to prefix AWS Config and Cloudtrail resources, including the S3 bucket names and SNS topics used for each."
  type        = string
  default     = "account-baseline-app"
}

variable "aws_region" {
  description = "The AWS Region to use as the global config recorder and seed region for AWS Guardduty."
  type        = string
  default     = "us-east-1"
}

variable "create_organization" {
  description = "Flag indicating whether the organization should be created."
  type        = bool
  default     = false
}

variable "child_accounts" {
  description = "Map of child accounts to create. The map key is the name of the account and the value is an object containing account configuration variables."

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
  # - parent_id:
  #   Parent Organizational Unit ID or Root ID for the account
  #   Defaults to the Organization default Root ID.
  #
  # - role_name:
  #   The name of an IAM role that Organizations automatically preconfigures in the new member account. This role trusts
  #   the master account, allowing users in the master account to assume the role, as permitted by the master account
  #   administrator. The role has administrator permissions in the new member account. Note that the Organizations API
  #   provides no method for reading this information after account creation.
  #   If no value is present and no ´default_role_name´ is provided, AWS automatically assigns a value.
  #
  # - iam_user_access_to_billing:
  #   If set to ´ALLOW´, the new account enables IAM users to access account billing information if they have the required
  #   permissions. If set to ´DENY´, then only the root user of the new account can access account billing information.
  #   Defaults to ´default_iam_user_access_to_billing´.
  #
  # - tags:
  #   Key-value mapping of resource tags.
  #
  #
  # Example:
  #
  # child_accounts = {
  #   security = {
  #     email                       = "security-master@acme.com",
  #     parent_id                   = "my-org-unit-id",
  #     role_name                   = "OrganizationAccountAccessRole",
  #     iam_user_access_to_billing  = "DENY",
  #     tags = {
  #       Tag-Key = "tag-value"
  #     }
  #   },
  #   sandbox = {
  #     email                       = "sandbox@acme.com"
  #   }
  # }

  default = {
    acme-example-security = {
      email                      = "security-user@acme.com",
      iam_user_access_to_billing = "ALLOW",
      tags = {
        Account-Tag-Example = "tag-value"
      }
    },
    sandbox = {
      email = "sandbox@acme.com"
    }
  }
}

variable "enable_config" {
  description = "Set to true to enable AWS Config in the root account. Set to false to disable AWS Config (note: all other AWS config variables will be ignored). Note that if you want to aggregate AWS Config data in an S3 bucket in a child account (e.g., a logs account), you MUST: (1) set this variable to false initially, as that S3 bucket doesn't exist yet in the child account, (2) run 'apply' to create the child account, (3) go to the child account and create the S3 bucket, e.g., by deploying a security baseline in that account, (4) come back to this root account and set this variable to true, and (5) run 'apply' again to enable AWS Config."
  type        = bool
  default     = true
}

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where Config items should be sent. We recommend the latter, setting this to the name of an S3 bucket in a separate logs account. However, see the description of var.enable_config for the steps you have to take to make this work."
  type        = string
  default     = null
}

variable "config_should_create_s3_bucket" {
  description = "If true, create an S3 bucket of name var.config_s3_bucket_name for AWS Config data in this account. If false, assume var.config_s3_bucket_name is an S3 bucket in another AWS account. We recommend setting this to false and using an S3 bucket in a separate logs account. However, see the description of var.enable_config for the steps you have to take to make this work."
  type        = bool
  default     = false
}

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account. If the S3 bucket and SNS topics live in this account, set this variable to null. We recommend storing AWS config data in a separate logs account and setting this variable to the ID of that account. However, see the description of var.enable_config for the steps you have to take to make this work."
  type        = string
  default     = null
}

variable "enable_cloudtrail" {
  description = "Set to true to enable CloudTrail in the root account. Set to false to disable CloudTrail (note: all other CloudTrail variables will be ignored). Note that if you want to aggregate CloudTrail logs in an S3 bucket in a child account (e.g., a logs account), you MUST: (1) set this variable to false initially, as that S3 bucket doesn't exist yet in the child account, (2) run 'apply' to create the child account, (3) go to the child account and create the S3 bucket, e.g., by deploying a security baseline in that account, (4) come back to this root account and set this variable to true, and (5) run 'apply' again to enable CloudTrail."
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where CloudTrail logs should be sent. We recommend the latter, setting this to the name of an S3 bucket in a separate logs account. However, see the description of var.enable_cloudtrail for the steps you have to take to make this work."
  type        = string
  default     = null
}

variable "cloudtrail_s3_bucket_already_exists" {
  description = "If false, create an S3 bucket of name var.cloudtrail_s3_bucket_name for CloudTrail logs in this account. If true, assume var.cloudtrail_s3_bucket_name is an S3 bucket in another AWS account. We recommend setting this to true and using an S3 bucket in a separate logs account. However, see the description of var.enable_cloudtrail for the steps you have to take to make this work."
  type        = bool
  default     = true
}

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists, set this to the ARN of that CMK. Otherwise, set this to null, and a new CMK will be created. We recommend setting this to the ARN of a CMK that already exists in a separate logs account. However, see the description of var.enable_cloudtrail for the steps you have to take to make this work."
  type        = string
  default     = null
}

variable "cloudtrail_cloudwatch_logs_group_name" {
  description = "Specify the name of the CloudWatch Logs group to publish the CloudTrail logs to. This log group exists in the current account. Set this value to `null` to avoid publishing the trail logs to the logs group. The recommended configuration for CloudTrail is (a) for each child account to aggregate its logs in an S3 bucket in a single central account, such as a logs account and (b) to also store 14 days work of logs in CloudWatch in the child account itself for local debugging."
  type        = string
  default     = "cloudtrail-logs"
}
