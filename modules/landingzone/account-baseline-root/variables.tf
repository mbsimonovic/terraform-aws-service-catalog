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
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL ORGANIZATIONS PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "create_organization" {
  description = "Flag indicating whether the organization should be created."
  type        = bool
  default     = true
}

variable "organizations_aws_service_access_principals" {
  description = "List of AWS service principal names for which you want to enable integration with your organization. Must have `organizations_feature_set` set to ALL. See https://docs.aws.amazon.com/organizations/latest/userguide/orgs_integrate_services.html"
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CONFIG RULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

# Common settings
variable "configrules_excluded_accounts" {
  description = "List of AWS account identifiers to exclude from the rules."
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

# RDS encryption
variable "enable_rds_storage_encrypted" {
  description = "Checks whether storage encryption is enabled for your RDS DB instances."
  type        = bool
  default     = true
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
  }))

  default = {}

  # Example:
  #
  # additional_rules = {
  #   acm-certificate-expiration-check = {
  #     description      = "Checks whether ACM Certificates in your account are marked for expiration within the specified number of days.",
  #     identifier       = "ACM_CERTIFICATE_EXPIRATION_CHECK",
  #     trigger_type     = "PERIODIC",
  #     input_parameters = { "daysToExpiration": "14"},
  #   }
  # }

}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL IAM-GROUPS PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "should_require_mfa" {
  description = "Should we require that all IAM Users use Multi-Factor Authentication for both AWS API calls and the AWS Web Console? (true or false)"
  type        = bool
  default     = true
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

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. If value is `null`, defaults to `var.name_prefix`-cloudtrail"
  type        = string
  default     = null
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
  description = "All CloudTrail Logs will be encrypted with a KMS Key (a Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. The IAM Users specified in this list will have rights to change who can access this extended log data."
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

variable "cloudtrail_s3_bucket_already_exists" {
  description = "If set to true, that means the S3 bucket you're using already exists, and does not need to be created. This is especially useful when using CloudTrail with multiple AWS accounts, with a common S3 bucket shared by all of them."
  type        = bool
  default     = false
}

variable "cloudtrail_external_aws_account_ids_with_write_access" {
  description = "A list of external AWS accounts that should be given write access for CloudTrail logs to this S3 bucket. This is useful when aggregating CloudTrail logs for multiple AWS accounts in one common S3 bucket."
  type        = list(string)
  default     = []
}

variable "cloudtrail_force_destroy" {
  description = "If set to true, when you run 'terraform destroy', delete all objects from the bucket so that the bucket can be destroyed without error. Warning: these objects are not recoverable so only use this if you're absolutely sure you want to permanently delete everything!"
  type        = bool
  default     = false
}
