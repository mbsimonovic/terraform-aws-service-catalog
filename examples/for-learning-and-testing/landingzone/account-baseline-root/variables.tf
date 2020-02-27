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
