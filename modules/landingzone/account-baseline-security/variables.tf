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
# OPTIONAL CONFIG PARAMETERS
# These variables have reasonable defaults that can be overridden for further customizations.
# ---------------------------------------------------------------------------------------------------------------------

variable "config_should_create_s3_bucket" {
  description = "Set to true to create an S3 bucket of name var.config_s3_bucket_name in this account for storing AWS Config data. Set to false to assume the bucket specified in var.config_s3_bucket_name already exists in another AWS account. We recommend setting this to false and setting var.config_s3_bucket_name to the name off an S3 bucket that already exists in a separate logs account."
  type        = bool
  default     = false
}

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where logs should be sent. We recommend setting this to the name of a bucket in a separate logs account."
  type        = string
  default     = null
}

variable "config_should_create_sns_topic" {
  description = "Set to true to create an SNS topic in this account for sending AWS Config notifications (e.g., if this is the logs account). Set to false to assume the topic specified in var.config_sns_topic_name already exists in another AWS account (e.g., if this is the stage or prod account and var.config_sns_topic_name is the name of an SNS topic in the logs account)."
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

variable "config_linked_accounts" {
  description = "Provide a list of AWS account IDs that will send Config data to this account. This is useful if your aggregating config data in this account for other accounts."
  type        = list(string)
  default     = []
}

variable "config_aggregate_config_data_in_external_account" {
  description = "Set to true to send the AWS Config data to another account (e.g., a logs account) for aggregation purposes. You must set the ID of that other account via the config_central_account_id variable. This redundant variable has to exist because Terraform does not allow computed data in count and for_each parameters and var.config_central_account_id may be computed if its the ID of a newly-created AWS account."
  type        = bool
  default     = false
}

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account. If the S3 bucket and SNS topics live in this account, set this variable to null. We recommend setting this to the ID of a separate logs account. Only used if var.config_aggregate_config_data_in_external_account is true."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CONFIG RULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

# Common settings
variable "config_create_account_rules" {
  description = "Set to true to create AWS Config rules directly in this account. Set false to not create any Config rules in this account (i.e., if you created the rules at the organization level already). We recommend setting this to true to use account-level rules because org-level rules create a chicken-and-egg problem with creating new accounts."
  type        = bool
  default     = true
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

# The only IAM groups you typically need in the security account are full access (for admins) and groups that allows
# access to other AWS accounts
variable "should_create_iam_group_full_access" {
  description = "Should we create the IAM Group for full access? Allows full access to all AWS resources. (true or false)"
  type        = bool
  default     = true
}

variable "should_create_iam_group_billing" {
  description = "Should we create the IAM Group for billing? Allows read-write access to billing features only. (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_support" {
  description = "Should we create the IAM Group for support? Allows support access (AWSupportAccess). (true or false)"
  type        = bool
  default     = false
}

variable "should_create_iam_group_logs" {
  description = "Should we create the IAM Group for logs? Allows read access to CloudTrail, AWS Config, and CloudWatch. If var.cloudtrail_kms_key_arn is set, will also give decrypt access to a KMS CMK. (true or false)"
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
  default     = true
}

variable "should_create_iam_group_iam_admin" {
  description = "Should we create the IAM Group for IAM administrator access? Allows users to manage all IAM entities, effectively granting administrator access. (true or false)"
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

variable "should_create_iam_group_cross_account_access_all" {
  description = "Should we create the IAM Group for access to all external AWS accounts? "
  type        = bool
  default     = true
}

variable "iam_group_name_full_access" {
  description = "The name to be used for the IAM Group that grants full access to all AWS resources."
  type        = string
  default     = "full-access"
}

variable "iam_group_name_billing" {
  description = "The name to be used for the IAM Group that grants read/write access to all billing features in AWS."
  type        = string
  default     = "billing"
}

variable "iam_group_name_support" {
  description = "The name of the IAM Group that allows access to AWS Support."
  type        = string
  default     = "support"
}

variable "iam_group_name_logs" {
  description = "The name to be used for the IAM Group that grants read access to CloudTrail, AWS Config, and CloudWatch in AWS."
  type        = string
  default     = "logs"
}

variable "iam_group_name_developers" {
  description = "The name to be used for the IAM Group that grants IAM Users a reasonable set of permissions for developers."
  type        = string
  default     = "developers"
}

variable "iam_group_name_read_only" {
  description = "The name to be used for the IAM Group that grants read-only access to all AWS resources."
  type        = string
  default     = "read-only"
}

variable "iam_group_names_ssh_grunt_sudo_users" {
  description = "The list of names to be used for the IAM Group that enables its members to SSH as a sudo user into any server configured with the ssh-grunt Gruntwork module. Pass in multiple to configure multiple different IAM groups to control different groupings of access at the server level. Pass in empty list to disable creation of the IAM groups."
  type        = list(string)
  default     = ["ssh-grunt-sudo-users"]
}

variable "iam_group_names_ssh_grunt_users" {
  description = "The name to be used for the IAM Group that enables its members to SSH as a non-sudo user into any server configured with the ssh-grunt Gruntwork module. Pass in multiple to configure multiple different IAM groups to control different groupings of access at the server level. Pass in empty list to disable creation of the IAM groups."
  type        = list(string)
  default     = ["ssh-grunt-users"]
}

variable "iam_group_name_use_existing_iam_roles" {
  description = "The name to be used for the IAM Group that grants IAM Users the permissions to use existing IAM Roles when launching AWS Resources. This does NOT grant the permission to create new IAM Roles."
  type        = string
  default     = "use-existing-iam-roles"
}

variable "iam_group_name_auto_deploy" {
  description = "The name of the IAM Group that allows automated deployment by graning the permissions specified in var.auto_deploy_permissions."
  type        = string
  default     = "_machine.ecs-auto-deploy"
}

variable "iam_group_name_houston_cli" {
  description = "The name of the IAM Group that allows access to houston CLI."
  type        = string
  default     = "houston-cli-users"
}

variable "iam_group_name_iam_user_self_mgmt" {
  description = "The name to be used for the IAM Group that grants IAM Users the permissions to manage their own IAM User account."
  type        = string
  default     = "iam-user-self-mgmt"
}

variable "iam_policy_iam_user_self_mgmt" {
  description = "The name to be used for the IAM Policy that grants IAM Users the permissions to manage their own IAM User account."
  type        = string
  default     = "iam-user-self-mgmt"
}

variable "iam_group_name_iam_admin" {
  description = "The name to be used for the IAM Group that grants IAM administrative access. Effectively grants administrator access."
  type        = string
  default     = "iam-admin"
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

variable "max_session_duration_human_users" {
  description = "The maximum allowable session duration, in seconds, for the credentials you get when assuming the IAM roles created by this module. This variable applies to all IAM roles created by this module that are intended for people to use, such as allow-read-only-access-from-other-accounts. For IAM roles that are intended for machine users, such as allow-auto-deploy-from-other-accounts, see var.max_session_duration_machine_users."
  type        = number
  default     = 43200 # 12 hours
}

variable "max_session_duration_machine_users" {
  description = "The maximum allowable session duration, in seconds, for the credentials you get when assuming the IAM roles created by this module. This variable  applies to all IAM roles created by this module that are intended for machine users, such as allow-auto-deploy-from-other-accounts. For IAM roles that are intended for human users, such as allow-read-only-access-from-other-accounts, see var.max_session_duration_human_users."
  type        = number
  default     = 3600 # 1 hour
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PASSWORD POLICY PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

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
  # users = {
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
  description = "A list of IAM ARNs from other AWS accounts that will be allowed support access (AWSSupportAccess) to this account."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:root"
  # ]
}

variable "allow_logs_access_from_other_account_arns" {
  description = "A list of IAM ARNs from other AWS accounts that will be allowed access to the logs in CloudTrail, AWS Config, and CloudWatch for this account. Will also be given permissions to decrypt with the KMS CMK that is used to encrypt CloudTrail logs."
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
  description = "Set to true (default) to enable CloudTrail in the security account. Set to false to disable CloudTrail (note: all other CloudTrail variables will be ignored). Note that if you have enabled organization trail in the root (parent) account, you should set this to false; the organization trail will enable CloudTrail on child accounts by default."
  type        = bool
  default     = true
}

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
  description = "Set to false to create an S3 bucket of name var.cloudtrail_s3_bucket_name in this account for storing CloudTrail logs. Set to true to assume the bucket specified in var.cloudtrail_s3_bucket_name already exists in another AWS account. We recommend setting this to true and setting var.cloudtrail_s3_bucket_name to the name of a bucket that already exists in a separate logs account."
  type        = bool
  default     = false
}

variable "cloudtrail_external_aws_account_ids_with_write_access" {
  description = "A list of external AWS accounts that should be given write access for CloudTrail logs to this S3 bucket. This is useful when aggregating CloudTrail logs for multiple AWS accounts in one common S3 bucket."
  type        = list(string)
  default     = []
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

variable "cloudtrail_cloudwatch_logs_group_name" {
  description = "Specify the name of the CloudWatch Logs group to publish the CloudTrail logs to. This log group exists in the current account. Set this value to `null` to avoid publishing the trail logs to the logs group. The recommended configuration for CloudTrail is (a) for each child account to aggregate its logs in an S3 bucket in a single central account, such as a logs account and (b) to also store 14 days work of logs in CloudWatch in the child account itself for local debugging."
  type        = string
  default     = "cloudtrail-logs"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL KMS PARAMETERS
# These variables must be passed in by the operator. In a real-world usage, some of these variables might not be needed
# and you can instead inline the values directly in main.tf.
# ---------------------------------------------------------------------------------------------------------------------

variable "kms_customer_master_keys" {
  description = "You can use this variable to create account-level KMS Customer Master Keys (CMKs) for encrypting and decrypting data. This variable should be a map where the keys are the names of the CMK and the values are an object that defines the configuration for that CMK. See the comment below for the configuration options you can set for each key."
  # Ideally, we will use a more strict type here but since we want to support required and optional values, and since
  # Terraform's type system only supports maps that have the same type for all values, we have to use the less useful
  # `any` type.
  type    = any
  default = {}

  # Each entry in the map supports the following attributes:
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - region                                  string                : The region (e.g., us-west-2) where the key should be created. If null or
  #                                                                   omitted, the key will be created in all enabled regions. Any keys
  #                                                                   targeting an opted out region or invalid region string will show up in the
  #                                                                   invalid_cmk_inputs output.
  # - cmk_administrator_iam_arns              list(string)          : A list of IAM ARNs for users who should be given
  #                                                                   administrator access to this CMK (e.g.
  #                                                                   arn:aws:iam::<aws-account-id>:user/<iam-user-arn>).
  # - cmk_user_iam_arns                       list(object[CMKUser]) : A list of IAM ARNs for users who should be given
  #                                                                   permissions to use this CMK (e.g.
  #                                                                   arn:aws:iam::<aws-account-id>:user/<iam-user-arn>).
  # - cmk_read_only_user_iam_arns             list(object[CMKUser]) : A list of IAM ARNs for users who should be given
  #                                                                   read-only (decrypt-only) permissions to use this CMK (e.g.
  #                                                                   arn:aws:iam::<aws-account-id>:user/<iam-user-arn>).
  # - cmk_external_user_iam_arns              list(string)          : A list of IAM ARNs for users from external AWS accounts
  #                                                                   who should be given permissions to use this CMK (e.g.
  #                                                                   arn:aws:iam::<aws-account-id>:root).
  # - allow_manage_key_permissions_with_iam   bool                  : If true, both the CMK's Key Policy and IAM Policies
  #                                                                   (permissions) can be used to grant permissions on the CMK.
  #                                                                   If false, only the CMK's Key Policy can be used to grant
  #                                                                   permissions on the CMK. False is more secure (and
  #                                                                   generally preferred), but true is more flexible and
  #                                                                   convenient.
  # - deletion_window_in_days                 number                : The number of days to keep this KMS Master Key around after it has been
  #                                                                   marked for deletion.
  # - tags                                    map(string)           : A map of tags to apply to the KMS Key to be created. In this map
  #                                                                   variable, the key is the tag name and the value  is the tag value. Note
  #                                                                   that this map is merged with var.global_tags, and can be used to override
  #                                                                   tags specified in that variable.
  # - enable_key_rotation                     bool                  : Whether or not to enable automatic annual rotation of the KMS key.
  # - spec                                    string                : Specifies whether the key contains a symmetric key or an asymmetric key
  #                                                                   pair and the encryption algorithms or signing algorithms that the key
  #                                                                   supports. Valid values: SYMMETRIC_DEFAULT, RSA_2048, RSA_3072, RSA_4096,
  #                                                                   ECC_NIST_P256, ECC_NIST_P384, ECC_NIST_P521, or ECC_SECG_P256K1.
  # - cmk_service_principals                  list(object[ServicePrincipal]) : A list of Service Principals that should be given
  #                                                                            permissions to use this CMK (e.g. s3.amazonaws.com). See
  #                                                                            below for the structure of the object that should be passed
  #                                                                            in.
  #
  # Structure of ServicePrincipal object:
  # - name          string                   : The name of the service principal (e.g.: s3.amazonaws.com).
  # - actions       list(string)             : The list of actions that the given service principal is allowed to
  #                                            perform (e.g. ["kms:DescribeKey", "kms:GenerateDataKey"]).
  # - conditions    list(object[Condition])  : (Optional) List of conditions to apply to the permissions for the service
  #                                            principal. Use this to apply conditions on the permissions for
  #                                            accessing the KMS key (e.g., only allow access for certain encryption
  #                                            contexts). The condition object accepts the same fields as the condition
  #                                            block on the IAM policy document (See
  #                                            https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html#condition).
  # Structure of CMKUser object:
  # - name          list(string)             : The list of names of the AWS principal (e.g.: arn:aws:iam::0000000000:user/dev).
  # - conditions    list(object[Condition])  : (Optional) List of conditions to apply to the permissions for the CMK User
  #                                            Use this to apply conditions on the permissions for accessing the KMS key
  #                                            (e.g., only allow access for certain encryption contexts).
  #                                            The condition object accepts the same fields as the condition
  #                                            block on the IAM policy document (See
  #                                            https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html#condition).
  # Example:
  # kms_customer_master_keys = {
  #   cmk-stage = {
  #     region                                = "us-west-1"
  #     cmk_administrator_iam_arns            = ["arn:aws:iam::0000000000:user/admin"]
  #     cmk_user_iam_arns                     = [
  #       {
  #         name = ["arn:aws:iam::0000000000:user/dev"]
  #         conditions = []
  #       }
  #     ]
  #     cmk_read_only_user_iam_arns           = [
  #       {
  #         name = ["arn:aws:iam::0000000000:user/qa"]
  #         conditions = []
  #       }
  #     ]
  #     cmk_external_user_iam_arns            = ["arn:aws:iam::1111111111:user/root"]
  #     cmk_service_principals                = [
  #       {
  #         name       = "s3.amazonaws.com"
  #         actions    = ["kms:Encrypt"]
  #         conditions = []
  #       }
  #     ]
  #   }
  #   cmk-prod = {
  #     region                                = "us-east-1"
  #     cmk_administrator_iam_arns            = ["arn:aws:iam::0000000000:user/admin"]
  #     cmk_user_iam_arns                     = [
  #       {
  #         name = ["arn:aws:iam::0000000000:user/prod"]
  #         conditions = []
  #       }
  #     ]
  #     allow_manage_key_permissions_with_iam = true
  #     # Override the default value for all keys configured with var.default_deletion_window_in_days
  #     deletion_window_in_days = 7
  #
  #     # Set extra tags on the CMK for prod
  #     tags = {
  #       Environment = "prod"
  #     }
  #   }
  # }
}

variable "kms_cmk_global_tags" {
  description = "A map of tags to apply to all KMS Keys to be created. In this map variable, the key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}

variable "kms_cmk_opt_in_regions" {
  description = "Creates KMS keys in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), KMS CMKs with region setting set to null will be created in all regions enabled on the account. Use this list to provide an alternate region list for testing purposes."
  type        = list(string)
  default     = null
}

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists, set this to the ARN of that CMK. Otherwise, set this to null, and a new CMK will be created. We recommend setting this to the ARN of a CMK that already exists in a separate logs account."
  type        = string
  default     = null
}

variable "kms_grant_regions" {
  description = "The map of names of KMS grants to the region where the key resides in. There should be a one to one mapping between entries in this map and the entries of the kms_grants map. This is used to workaround a terraform limitation where the for_each value can not depend on resources."
  type        = map(string)
  default     = {}
}

variable "kms_grants" {
  description = "Create the specified KMS grants to allow entities to use the KMS key without modifying the KMS policy or IAM. This is necessary to allow AWS services (e.g. ASG) to use CMKs encrypt and decrypt resources. The input is a map of grant name to grant properties. The name must be unique per account."
  type = map(object({
    # ARN of the KMS CMK that the grant applies to. Note that the region is introspected based on the ARN.
    kms_cmk_arn = string

    # The principal that is given permission to perform the operations that the grant permits. This must be in ARN
    # format. For example, the grantee principal for ASG is:
    # arn:aws:iam::111122223333:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling
    grantee_principal = string

    # A list of operations that the grant permits. The permitted values are:
    # Decrypt, Encrypt, GenerateDataKey, GenerateDataKeyWithoutPlaintext, ReEncryptFrom, ReEncryptTo, CreateGrant,
    # RetireGrant, DescribeKey
    granted_operations = list(string)
  }))
  default = {}
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
  description = "If set to true, the KMS Customer Managed Keys (CMK) with the name in var.ebs_kms_key_name will be set as the default for EBS encryption. When false (default), the AWS-managed aws/ebs key will be used."
  type        = bool
  default     = false
}

variable "ebs_kms_key_name" {
  description = "The name of the KMS CMK to use by default for encrypting EBS volumes, if var.ebs_enable_encryption and var.ebs_use_existing_kms_keys are enabled. The name must match a name given the var.kms_customer_master_keys variable."
  type        = string
  default     = ""
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
