# ---------------------------------------------------------------------------------------------------------------------
# COMMON PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "name_prefix" {
  description = "The name used to prefix AWS Config and Cloudtrail resources, including the S3 bucket names and SNS topics used for each."
  type        = string
}

variable "aws_region" {
  description = "The AWS Region to use as the global config recorder and seed region for GuardDuty."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS Account ID the template should be operated on. This avoids misconfiguration errors caused by environment variables."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED ORGANIZATIONS PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

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
  #   If no value is present and no ´default_role_name´ is provided, AWS automatically assigns a value.
  #
  # - iam_user_access_to_billing:
  #   If set to ´ALLOW´, the new account enables IAM users to access account billing information if they have the required
  #   permissions. If set to ´DENY´, then only the root user of the new account can access account billing information.
  #   Defaults to ´default_iam_user_access_to_billing´.
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
# OPTIONAL ORGANIZATIONS PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "create_organization" {
  description = "Set to true to create/configure AWS Organizations for the first time in this account. If you already configured AWS Organizations in your account, set this to false; alternatively, you could set it to true and run 'terraform import' to import you existing Organization."
  type        = bool
  default     = true
}

variable "organizations_aws_service_access_principals" {
  description = "List of AWS service principal names for which you want to enable integration with your organization. Must have `organizations_feature_set` set to ALL. See https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html"
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
    "config.amazonaws.com",
    "access-analyzer.amazonaws.com",
  ]
}

variable "organizations_enabled_policy_types" {
  description = "List of Organizations policy types to enable in the Organization Root. See https://docs.aws.amazon.com/organizations/latest/APIReference/API_EnablePolicyType.html"
  type        = list(string)
  default     = ["SERVICE_CONTROL_POLICY"]
}

variable "organizations_feature_set" {
  description = "Specify `ALL` or `CONSOLIDATED_BILLING`."
  type        = string
  default     = "ALL"
}

variable "organizations_default_iam_user_access_to_billing" {
  description = "If set to ALLOW, the new account enables IAM users to access account billing information if they have the required permissions. If set to DENY, then only the root user of the new account can access account billing information."
  type        = string
  default     = "ALLOW"
}

variable "organizations_default_role_name" {
  description = "The name of an IAM role that Organizations automatically preconfigures in the new member account. This role trusts the master account, allowing users in the master account to assume the role, as permitted by the master account administrator."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "organizations_default_tags" {
  description = "Default tags to add to accounts. Will be appended to ´child_account.*.tags´"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CONFIG RULES PARAMETERS
# These variables have reasonable defaults that can be overridden for further customizations.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_config" {
  description = "Set to true to enable AWS Config in the root account. Set to false to disable AWS Config (note: all other AWS config variables will be ignored). In case you want to disable the CloudTrail module and the S3 bucket, you need to set both var.enable_cloudtrail and cloudtrail_should_create_s3_bucket to false."
  type        = bool
  default     = true
}

variable "config_should_create_s3_bucket" {
  description = "If true, create an S3 bucket of name var.config_s3_bucket_name for AWS Config data, either in the logs account—the account in var.child_accounts that has is_logs_account set to true (this is the recommended approach!)—or in this account if none of the child accounts are marked as a logs account. If false, assume var.config_s3_bucket_name is an S3 bucket that already exists. We recommend setting this to true and setting is_logs_account to true on one of the accounts in var.child_accounts to use that account as a logs account where you aggregate all your AWS Config data. In case you want to disable the AWS Config module and the S3 bucket, you need to set both var.enable_config and config_should_create_s3_bucket to false."
  type        = bool
  default     = true
}

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where Config items should be sent. If you set is_logs_account to true on one of the accounts in var.child_accounts, the S3 bucket will be created in that account (this is the recommended approach!)."
  type        = string
  default     = null
}

variable "config_s3_mfa_delete" {
  description = "Enable MFA delete for either 'Change the versioning state of your bucket' or 'Permanently delete an object version'. This setting only applies to the bucket used to storage AWS Config data. This cannot be used to toggle this setting but is available to allow managed buckets to reflect the state in AWS. CIS v1.4 requires this variable to be true. If you do not wish to be CIS-compliant, you can set it to false."
  type        = bool
  default     = false
}

variable "config_s3_enable_lifecycle_rules" {
  description = "If you enable MFA Delete, you need to disable Lifecycle Rules for the bucket."
  type        = bool
  default     = true
}

variable "config_should_create_sns_topic" {
  description = "Set to true to create an SNS topic in this account for sending AWS Config notifications. Set to false to assume the topic specified in var.config_sns_topic_name already exists in another AWS account (e.g the logs account)."
  type        = bool
  default     = false
}

variable "config_sns_topic_name" {
  description = "The name of the SNS Topic in where AWS Config notifications will be sent. Can be in the same account or in another account."
  type        = string
  default     = "ConfigTopic"
}

variable "config_opt_in_regions" {
  description = "Creates resources in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), AWS Config will be enabled on all regions enabled on the account. Please note that the best practice is to enable AWS Config in all available regions. Use this list to provide an alternate region list for testing purposes"
  type        = list(string)
  default     = null
}

variable "config_num_days_after_which_archive_log_data" {
  description = "After this number of days, log files should be transitioned from S3 to Glacier. Enter 0 to never archive log data."
  type        = number
  default     = 365
}

variable "config_num_days_after_which_delete_log_data" {
  description = "After this number of days, log files should be deleted from S3. Enter 0 to never delete log data."
  type        = number
  default     = 730
}

variable "config_force_destroy" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from the bucket so that the bucket can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything!"
  type        = bool
  default     = false
}

variable "config_tags" {
  description = "A map of tags to apply to the S3 Bucket. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

variable "config_aggregate_config_data_in_external_account" {
  description = "Set to true to send the AWS Config data to another account (e.g., a logs account) for aggregation purposes. You must set the ID of that other account via the config_central_account_id variable. Note that if one of the accounts in var.child_accounts has is_logs_account set to true (this is the approach we recommended!), this variable will be assumed to be true, so you don't have to pass any value for it.  This redundant variable has to exist because Terraform does not allow computed data in count and for_each parameters and var.config_central_account_id may be computed if its the ID of a newly-created AWS account."
  type        = bool
  default     = false
}

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account. If the S3 bucket and SNS topics live in this account, set this variable to an empty string. Note that if one of the accounts in var.child_accounts has is_logs_account set to true (this is the approach we recommended!), that account's ID will be used automatically, and you can leave this variable null."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CONFIG RULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

# Common settings
variable "config_create_account_rules" {
  description = "Set to true to create account-level AWS Config rules directly in this account. Set false to create org-level rules that apply to this account and all child accounts. We recommend setting this to true to use account-level rules because org-level rules create a chicken-and-egg problem with creating new accounts (see this module's README for details)."
  type        = bool
  default     = true
}

variable "configrules_excluded_accounts" {
  description = "List of AWS account identifiers to exclude from org-level Config rules. Only used if var.config_create_account_rules is false (not recommended)."
  type        = list(string)
  default     = []
}

variable "configrules_maximum_execution_frequency" {
  description = "The maximum frequency with which AWS Config runs evaluations for the ´PERIODIC´ rules. See https://www.terraform.io/docs/providers/aws/r/config_organization_managed_rule.html#maximum_execution_frequency"
  type        = string
  default     = "TwentyFour_Hours"
}

# Password policy
variable "enable_iam_password_policy" {
  description = "Checks whether the account password policy for IAM users meets the specified requirements."
  type        = bool
  default     = true
}

variable "iam_password_policy_require_uppercase_characters" {
  description = "Require at least one uppercase character in password."
  type        = bool
  default     = true
}

variable "iam_password_policy_require_lowercase_characters" {
  description = "Require at least one lowercase character in password."
  type        = bool
  default     = true
}

variable "iam_password_policy_require_symbols" {
  description = "Require at least one symbol in password."
  type        = bool
  default     = true
}

variable "iam_password_policy_require_numbers" {
  description = "Require at least one number in password."
  type        = bool
  default     = true
}

variable "iam_password_policy_minimum_password_length" {
  description = "Password minimum length."
  type        = number
  default     = 16
}

variable "iam_password_policy_password_reuse_prevention" {
  description = "Number of passwords before allowing reuse."
  type        = number
  default     = 5
}

variable "iam_password_policy_max_password_age" {
  description = "Number of days before password expiration."
  type        = number
  default     = 30
}

variable "iam_password_policy_allow_users_to_change_password" {
  description = "Allow users to change their own password."
  type        = bool
  default     = true
}

#
# WARNING: Setting the below value to "true" with the following conditions can lead to administrative account lockout:
#
# 1) You have only a single administrative IAM user
# 2) You do not have access to the root account
#
variable "iam_password_policy_hard_expiry" {
  description = "Password expiration requires administrator reset."
  type        = bool
  default     = true
}

variable "enable_insecure_sg_rules" {
  description = "Checks whether the security group with 0.0.0.0/0 of any Amazon Virtual Private Cloud (Amazon VPC) allows only specific inbound TCP or UDP traffic."
  type        = bool
  default     = true
}

variable "insecure_sg_rules_authorized_tcp_ports" {
  description = "Comma-separated list of TCP ports authorized to be open to 0.0.0.0/0. Ranges are defined by a dash; for example, '443,1020-1025'."
  type        = string
  default     = "443"
}

variable "insecure_sg_rules_authorized_udp_ports" {
  description = "Comma-separated list of UDP ports authorized to be open to 0.0.0.0/0. Ranges are defined by a dash; for example, '500,1020-1025'."
  type        = string
  default     = null
}

# S3 Public read prohibited
variable "enable_s3_bucket_public_read_prohibited" {
  description = "Checks that your Amazon S3 buckets do not allow public read access."
  type        = bool
  default     = true
}

# S3 Public write prohibited
variable "enable_s3_bucket_public_write_prohibited" {
  description = "Checks that your Amazon S3 buckets do not allow public write access."
  type        = bool
  default     = true
}

# Root account MFA
variable "enable_root_account_mfa" {
  description = "Checks whether users of your AWS account require a multi-factor authentication (MFA) device to sign in with root credentials."
  type        = bool
  default     = true
}

# EBS encryption
variable "enable_encrypted_volumes" {
  description = "Checks whether the EBS volumes that are in an attached state are encrypted."
  type        = bool
  default     = true
}

variable "encrypted_volumes_kms_id" {
  description = "ID or ARN of the KMS key that is used to encrypt the volume. Used for configuring the encrypted volumes config rule."
  type        = string
  default     = null
}

# RDS encryption
variable "enable_rds_storage_encrypted" {
  description = "Checks whether storage encryption is enabled for your RDS DB instances."
  type        = bool
  default     = true
}

variable "rds_storage_encrypted_kms_id" {
  description = "KMS key ID or ARN used to encrypt the storage. Used for configuring the RDS storage encryption config rule."
  type        = string
  default     = null
}

variable "additional_config_rules" {
  description = "Map of additional managed rules to add. The key is the name of the rule (e.g. ´acm-certificate-expiration-check´) and the value is an object specifying the rule details"
  type = map(object({
    # Description of the rule
    description : string
    # Identifier of an available AWS Config Managed Rule to call.
    identifier : string
    # Trigger type of the rule, must be one of ´CONFIG_CHANGE´ or ´PERIODIC´.
    trigger_type : string
    # A map of input parameters for the rule. If you don't have parameters, pass in an empty map ´{}´.
    input_parameters : map(string)
    # Whether or not this applies to global (non-regional) resources like IAM roles. When true, these rules are disabled
    # if var.enable_global_resource_rules is false.
    applies_to_global_resources = bool
  }))

  default = {}

  # Example:
  #
  # additional_config_rules = {
  #   acm-certificate-expiration-check = {
  #     description                 = "Checks whether ACM Certificates in your account are marked for expiration within the specified number of days.",
  #     identifier                  = "ACM_CERTIFICATE_EXPIRATION_CHECK",
  #     trigger_type                = "PERIODIC",
  #     input_parameters            = { "daysToExpiration": "14"},
  #     applies_to_global_resources = false
  #   }
  # }

}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL IAM-GROUPS PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_iam_groups" {
  description = "A feature flag to enable or disable this module."
  type        = bool
  default     = true
}

variable "enable_iam_cross_account_roles" {
  description = "A feature flag to enable or disable this module."
  type        = bool
  default     = true
}

variable "should_require_mfa" {
  description = "Should we require that all IAM Users use Multi-Factor Authentication for both AWS API calls and the AWS Web Console? (true or false)"
  type        = bool
  default     = true
}

variable "iam_role_tags" {
  description = "The tags to apply to all the IAM role resources."
  type        = map(string)
  default     = {}
}

variable "iam_group_developers_permitted_services" {
  description = "A list of AWS services for which the developers IAM Group will receive full permissions. See https://goo.gl/ZyoHlz to find the IAM Service name. For example, to grant developers access only to EC2 and Amazon Machine Learning, use the value [\"ec2\",\"machinelearning\"]. Do NOT add iam to the list of services, or that will grant Developers de facto admin access. If you need to grant iam privileges, just grant the user Full Access."
  type        = list(string)
  default     = []
}

variable "iam_groups_for_cross_account_access" {
  description = "This variable is used to create groups that allow IAM users to assume roles in your other AWS accounts. It should be a list of objects, where each object has the fields 'group_name', which will be used as the name of the IAM group, and 'iam_role_arns', which is a list of ARNs of IAM Roles that you can assume when part of that group. For each entry in the list of objects, we will create an IAM group that allows users to assume the given IAM role(s) in the other AWS account. This allows you to define all your IAM users in one account (e.g. the users account) and to grant them access to certain IAM roles in other accounts (e.g. the stage, prod, audit accounts)."
  type = list(object({
    group_name    = string
    iam_role_arns = list(string)
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     group_name   = "stage-full-access"
  #     iam_role_arns = ["arn:aws:iam::123445678910:role/mgmt-full-access"]
  #   },
  #   {
  #     group_name   = "prod-read-only-access"
  #     iam_role_arns = [
  #       "arn:aws:iam::9876543210:role/prod-read-only-ec2-access",
  #       "arn:aws:iam::9876543210:role/prod-read-only-rds-access"
  #     ]
  #   }
  # ]
}

# The only IAM groups you need in the root account are full access (for admins) and billing (for the finance team)
variable "should_create_iam_group_full_access" {
  description = "Should we create the IAM Group for full access? Allows full access to all AWS resources. (true or false)"
  type        = bool
  default     = true
}

variable "should_create_iam_group_billing" {
  description = "Should we create the IAM Group for billing? Allows read-write access to billing features only. (true or false)"
  type        = bool
  default     = true
}

variable "should_create_iam_group_support" {
  description = "Should we create the IAM Group for support? Allows access to AWS support. (true or false)"
  type        = bool
  default     = true
}

variable "should_create_iam_group_logs" {
  description = "Should we create the IAM Group for logs? Allows read access to logs in CloudTrail, AWS Config, and CloudWatch. If var.cloudtrail_kms_key_arn is specified, will also be given permissions to decrypt with the KMS CMK that is used to encrypt CloudTrail logs. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_developers" {
  description = "Should we create the IAM Group for developers? The permissions of that group are specified via var.iam_group_developers_permitted_services. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_read_only" {
  description = "Should we create the IAM Group for read-only? Allows read-only access to all AWS resources. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_user_self_mgmt" {
  description = "Should we create the IAM Group for user self-management? Allows users to manage their own IAM user accounts, but not other IAM users. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_use_existing_iam_roles" {
  description = "Should we create the IAM Group for use-existing-iam-roles? Allow launching AWS resources with existing IAM Roles, but no ability to create new IAM Roles. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_auto_deploy" {
  description = "Should we create the IAM Group for auto-deploy? Allows automated deployment by granting the permissions specified in var.auto_deploy_permissions. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_houston_cli_users" {
  description = "Should we create the IAM Group for houston CLI users? Allows users to use the houston CLI for managing and deploying services."
  type        = bool
  default     = false
}

variable "cross_account_access_all_group_name" {
  description = "The name of the IAM group that will grant access to all external AWS accounts in var.iam_groups_for_cross_account_access."
  type        = string
  default     = "_all-accounts"
}

variable "auto_deploy_permissions" {
  description = "A list of IAM permissions (e.g. ec2:*) that will be added to an IAM Group for doing automated deployments. NOTE: If var.should_create_iam_group_auto_deploy is true, the list must have at least one element (e.g. '*')."
  type        = list(string)
  default     = []
}
# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL USERS MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

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

variable "force_destroy_users" {
  description = "When destroying this user, destroy even if it has non-Terraform-managed IAM access keys, login profile, or MFA devices. Without force_destroy a user with non-Terraform-managed access keys and login profile will fail to be destroyed."
  type        = bool
  default     = false
}

variable "password_reset_required" {
  description = "Force the user to reset their password on initial login. Only used for users with create_login_profile set to true."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CROSS ACCOUNT IAM ROLES PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "dev_permitted_services" {
  description = "A list of AWS services for which the developers from the accounts in var.allow_dev_access_from_other_account_arns will receive full permissions. See https://goo.gl/ZyoHlz to find the IAM Service name. For example, to grant developers access only to EC2 and Amazon Machine Learning, use the value [\"ec2\",\"machinelearning\"]. Do NOT add iam to the list of services, or that will grant Developers de facto admin access."
  type        = list(string)
  default     = []
}

variable "allow_read_only_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed read-only access to this account."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_billing_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed full (read and write) access to the billing info for this account."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_support_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed access to AWS support for this account."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_logs_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed read access to the logs in CloudTrail, AWS Config, and CloudWatch for this account. If var.cloudtrail_kms_key_arn is specified, will also be given permissions to decrypt with the KMS CMK that is used to encrypt CloudTrail logs."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_ssh_grunt_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed read access to IAM groups and publish SSH keys. This is used for ssh-grunt."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_dev_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed full (read and write) access to the services in this account specified in var.dev_permitted_services."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_full_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed full (read and write) access to this account."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_auto_deploy_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed to assume the auto deploy IAM role that has the permissions in var.auto_deploy_permissions."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:role/jenkins"
  # ]
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL GUARDDUTY PARAMETERS
# These variables must be passed in by the operator. In a real-world usage, some of these variables might not be needed
# and you can instead inline the values directly in main.tf.
# ---------------------------------------------------------------------------------------------------------------------

variable "guardduty_publish_findings_to_sns" {
  description = "Send GuardDuty findings to SNS topics specified by findings_sns_topic_name."
  type        = bool
  default     = false
}

variable "guardduty_findings_sns_topic_name" {
  description = "Specifies a name for the created SNS topics where findings are published. publish_findings_to_sns must be set to true."
  type        = string
  default     = "guardduty-findings"
}

variable "guardduty_cloudwatch_event_rule_name" {
  description = "Name of the Cloudwatch event rules."
  type        = string
  default     = "guardduty-finding-events"
}

variable "guardduty_finding_publishing_frequency" {
  description = "Specifies the frequency of notifications sent for subsequent finding occurrences. If the detector is a GuardDuty member account, the value is determined by the GuardDuty master account and cannot be modified, otherwise defaults to SIX_HOURS. For standalone and GuardDuty master accounts, it must be configured in Terraform to enable drift detection. Valid values for standalone and master accounts: FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS."
  type        = string
  default     = null
}

variable "guardduty_opt_in_regions" {
  description = "Creates resources in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), AWS Config will be enabled on all regions enabled on the account. Please note that the best practice is to enable AWS Config in all available regions. Use this list to provide an alternate region list for testing purposes"
  type        = list(string)
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CLOUDTRAIL PARAMETERS
# These variables must be passed in by the operator. In a real-world usage, some of these variables might not be needed
# and you can instead inline the values directly in main.tf.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_cloudtrail" {
  description = "Set to true to enable CloudTrail in the root account. Set to false to disable CloudTrail (note: all other CloudTrail variables will be ignored). In case you want to disable the CloudTrail module and the S3 bucket, you need to set both var.enable_cloudtrail and cloudtrail_should_create_s3_bucket to false."
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Specifies whether CloudTrail will log only API calls in the current region or in all regions. (true or false)"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where CloudTrail logs should be sent. If you set is_logs_account on one of the accounts in var.child_accounts, the S3 bucket will be created in that account (this is the recommended approach!)."
  type        = string
  default     = null
}

variable "cloudtrail_s3_mfa_delete" {
  description = "Enable MFA delete for either 'Change the versioning state of your bucket' or 'Permanently delete an object version'. This setting only applies to the bucket used to storage Cloudtrail data. This cannot be used to toggle this setting but is available to allow managed buckets to reflect the state in AWS. CIS v1.4 requires this variable to be true. If you do not wish to be CIS-compliant, you can set it to false."
  type        = bool
  default     = false
}

variable "cloudtrail_s3_enable_lifecycle_rules" {
  description = "If you enable MFA Delete, you need to disable Lifecycle Rules for the bucket."
  type        = bool
  default     = true
}

variable "enable_cloudtrail_s3_server_access_logging" {
  description = "Enables S3 server access logging which sends detailed records for the requests that are made to the bucket. Defaults to false."
  type        = bool
  default     = false
}

variable "cloudtrail_num_days_after_which_archive_log_data" {
  description = "After this number of days, log files should be transitioned from S3 to Glacier. Enter 0 to never archive log data."
  type        = number
  default     = 30
}

variable "cloudtrail_num_days_after_which_delete_log_data" {
  description = "After this number of days, log files should be deleted from S3. Enter 0 to never delete log data."
  type        = number
  default     = 365
}

variable "cloudtrail_kms_key_administrator_iam_arns" {
  description = "All CloudTrail Logs will be encrypted with a KMS Key (a Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. The IAM Users specified in this list will have rights to change who can access this extended log data. Note that if you specify a logs account (by setting is_logs_account = true on one of the accounts in var.child_accounts), the KMS CMK will be created in that account, and the root of that account will automatically be made an admin of the CMK."
  type        = list(string)
  # example = ["arn:aws:iam::<aws-account-id>:user/<iam-user-name>"]
  default = []
}

variable "cloudtrail_kms_key_user_iam_arns" {
  description = "All CloudTrail Logs will be encrypted with a KMS Key (a Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. The IAM Users specified in this list will have read-only access to this extended log data."
  type        = list(string)
  # example = ["arn:aws:iam::<aws-account-id>:user/<iam-user-name>"]
  default = []
}

variable "allow_cloudtrail_access_with_iam" {
  description = "If true, an IAM Policy that grants access to CloudTrail will be honored. If false, only the ARNs listed in var.kms_key_user_iam_arns will have access to CloudTrail and any IAM Policy grants will be ignored. (true or false)"
  type        = bool
  default     = true
}

variable "cloudtrail_should_create_s3_bucket" {
  description = "If true, create an S3 bucket of name var.cloudtrail_s3_bucket_name for CloudTrail logs, either in the logs account—the account in var.child_accounts that has is_logs_account set to true (this is the recommended approach!)—or in this account if none of the child accounts are marked as a logs account. If false, assume var.cloudtrail_s3_bucket_name is an S3 bucket that already exists. We recommend setting this to true and setting is_logs_account to true on one of the accounts in var.child_accounts to use that account as a logs account where you aggregate all your CloudTrail data. In case you want to disable the CloudTrail module and the S3 bucket, you need to set both var.enable_cloudtrail and cloudtrail_should_create_s3_bucket to false."
  type        = bool
  default     = true
}

variable "cloudtrail_tags" {
  description = "Tags to apply to the CloudTrail resources."
  type        = map(string)
  default     = {}
}

variable "cloudtrail_force_destroy" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from the bucket so that the bucket can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything!"
  type        = bool
  default     = false
}

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists, set this to the ARN of that CMK. Otherwise, set this to null, and a new CMK will be created. If you set is_logs_account to true on one of the accounts in var.child_accounts, the KMS CMK will be created in that account (this is the recommended approach!)."
  type        = string
  default     = null
}

variable "cloudtrail_enable_key_rotation" {
  description = "Whether or not to enable automatic annual rotation of the KMS key. Defaults to true."
  type        = bool
  default     = true
}

variable "cloudtrail_allow_kms_describe_key_to_external_aws_accounts" {
  description = "Whether or not to allow kms:DescribeKey to external AWS accounts with write access to the CloudTrail bucket. This is useful during deployment so that you don't have to pass around the KMS key ARN."
  type        = bool
  default     = false
}

variable "cloudtrail_kms_key_arn_is_alias" {
  description = "If the kms_key_arn provided is an alias or alias ARN, then this must be set to true so that the module will exchange the alias for a CMK ARN. Setting this to true and using aliases requires var.cloudtrail_allow_kms_describe_key_to_external_aws_accounts to also be true for multi-account scenarios."
  type        = bool
  default     = false
}

variable "cloudtrail_cloudwatch_logs_group_name" {
  description = "Specify the name of the CloudWatch Logs group to publish the CloudTrail logs to. This log group exists in the current account. Set this value to `null` to avoid publishing the trail logs to the logs group. The recommended configuration for CloudTrail is (a) for each child account to aggregate its logs in an S3 bucket in a single central account, such as a logs account and (b) to also store 14 days work of logs in CloudWatch in the child account itself for local debugging."
  type        = string
  default     = "cloudtrail-logs"
}

variable "cloudtrail_num_days_to_retain_cloudwatch_logs" {
  description = "After this number of days, logs stored in CloudWatch will be deleted. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653, and 0 (default). When set to 0, logs will be retained indefinitely."
  type        = number
  default     = 0
}

variable "cloudtrail_is_organization_trail" {
  description = "Specifies whether the trail is an AWS Organizations trail. Organization trails log events for the root account and all member accounts. Can only be created in the organization root account. (true or false)"
  type        = bool
  default     = false
}

variable "cloudtrail_organization_id" {
  description = "The ID of the organization. Required only if an organization wide CloudTrail is being setup and `create_organization` is set to false. The organization ID is required to ensure that the entire organization is whitelisted in the CloudTrail bucket write policy."
  type        = string
  default     = null
}

variable "cloudtrail_data_logging_enabled" {
  description = "If true, logging of data events will be enabled."
  type        = bool
  default     = false
}

variable "cloudtrail_data_logging_read_write_type" {
  description = "Specify if you want your trail to log read-only events, write-only events, or all. Possible values are: ReadOnly, WriteOnly, All."
  type        = string
  default     = "All"
}

variable "cloudtrail_data_logging_include_management_events" {
  description = "Specify if you want your event selector to include management events for your trail."
  type        = bool
  default     = true
}

variable "cloudtrail_data_logging_resource_type" {
  description = "The resource type in which you want to log data events. Possible values are: AWS::S3::Object and AWS::Lambda::Function."
  type        = string
  default     = "AWS::S3::Object"
}

variable "cloudtrail_data_logging_resource_values" {
  description = "A list of resource ARNs for data event logging."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL EBS ENCRYPTION PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "ebs_enable_encryption" {
  description = "If set to true (default), all new EBS volumes will have encryption enabled by default"
  type        = bool
  default     = true
}

variable "ebs_use_existing_kms_keys" {
  description = "If set to true, the KMS Customer Managed Keys (CMK) specified in var.ebs_kms_key_arns will be set as the default for EBS encryption. When false (default), the AWS-managed aws/ebs key will be used."
  type        = bool
  default     = false
}

variable "ebs_kms_key_arns" {
  description = "Optional map of region names to KMS keys to use for EBS volume encryption when var.ebs_use_existing_kms_keys is enabled."
  type        = map(string)
  default     = {}
  # Example:
  # kms_key_arns = {
  #   "af-south-1": "arn:arn:aws:kms:af-south-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  #   "ap-southeast-1": "arn:arn:aws:kms:ap-southeast-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  # }
}

variable "ebs_opt_in_regions" {
  description = "Configures EBS encryption defaults in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), EBS encryption will be enabled on all regions enabled on the account. Use this list to provide an alternate region list for testing purposes."
  type        = list(string)
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED IAM ACCESS ANALYZER PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------
variable "enable_iam_access_analyzer" {
  description = "A feature flag to enable or disable this module."
  type        = bool
  default     = false
}

variable "iam_access_analyzer_type" {
  description = "If set to ORGANIZATION, the analyzer will be scanning the current organization and any policies that refer to linked resources such as S3, IAM, Lambda and SQS policies."
  type        = string
  default     = "ORGANIZATION"
}

variable "iam_access_analyzer_name" {
  description = "The name of the IAM Access Analyzer module"
  type        = string
  default     = "baseline_root-iam_access_analyzer"
}

variable "iam_access_analyzer_opt_in_regions" {
  description = "Enables IAM Access Analyzer defaults in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), IAM Access Analyzer will be enabled on all regions enabled on the account. Use this list to provide an alternate region list for testing purposes"
  type        = list(string)
  default     = null
}
