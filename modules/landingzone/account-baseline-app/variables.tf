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

variable "enable_config" {
  description = "Set to true to enable AWS Config in the root account. Set to false to disable AWS Config (note: all other AWS config variables will be ignored). Note that if you want to aggregate AWS Config data in an S3 bucket in a child account (e.g., a logs account), you MUST: (1) set this variable to false initially, as that S3 bucket doesn't exist yet in the child account, (2) run 'apply' to create the child account, (3) go to the child account and create the S3 bucket, e.g., by deploying a security baseline in that account, (4) come back to this root account and set this variable to true, and (5) run 'apply' again to enable AWS Config."
  type        = bool
  default     = true
}

variable "config_should_create_s3_bucket" {
  description = "Set to true to create an S3 bucket of name var.config_s3_bucket_name in this account for storing AWS Config data (e.g., if this is the logs account). Set to false to assume the bucket specified in var.config_s3_bucket_name already exists in another AWS account (e.g., if this is the stage or prod account and var.config_s3_bucket_name is the name of a bucket in the logs account)."
  type        = bool
  default     = false
}

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. Can be in the same account or in another account."
  type        = string
  default     = null
}

variable "config_should_create_sns_topic" {
  description = "set to true to create an sns topic in this account for sending aws config notifications (e.g., if this is the logs account). set to false to assume the topic specified in var.config_sns_topic_name already exists in another aws account (e.g., if this is the stage or prod account and var.config_sns_topic_name is the name of an sns topic in the logs account)."
  type        = bool
  default     = false
}

variable "config_sns_topic_name" {
  description = "the name of the sns topic in where aws config notifications will be sent. can be in the same account or in another account."
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
  description = "Provide a list of AWS account IDs that will be allowed to send AWS Config data to this account. This is only required if you are aggregating config data in this account (e.g., this is the logs account) from other accounts."
  type        = list(string)
  default     = []
}

variable "config_aggregate_config_data_in_external_account" {
  description = "Set to true to send the AWS Config data to another account (e.g., a logs account) for aggregation purposes. You must set the ID of that other account via the config_central_account_id variable. This redundant variable has to exist because Terraform does not allow computed data in count and for_each parameters and var.config_central_account_id may be computed if its the ID of a newly-created AWS account."
  type        = bool
  default     = false
}

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account (e.g., if this is the stage or prod account, set this to the ID of the logs account). If the S3 bucket and SNS topics live in this account (e.g., this is the logs account), set this variable to null. Only used if var.config_aggregate_config_data_in_external_account is true."
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
# OPTIONAL PASSWORD POLICY PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_iam_user_password_policy" {
  description = "Set to true (default) to enable the IAM User Password Policies in this app account. Set to false to disable the policies. (Note: all other IAM User Password Policy variables will be ignored)."
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CROSS ACCOUNT IAM ROLES PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

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
  description = "Set to true (default) to enable CloudTrail in this app account. Set to false to disable CloudTrail (note: all other CloudTrail variables will be ignored). Note that if you have enabled organization trail in the root (parent) account, you should set this to false; the organization trail will enable CloudTrail on child accounts by default."
  type        = bool
  default     = true
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

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists (e.g., if this is the stage or prod account and you want to use a CMK that already exists in the logs account), set this to the ARN of that CMK. Otherwise (e.g., if this is the logs account), set this to null, and a new CMK will be created."
  type        = string
  default     = null
}

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account (e.g., if this is the logs account) or the name of a bucket in another AWS account where logs should be sent (e.g., if this is the stage or prod account and you're specifying the name of a bucket in the logs account)."
  type        = string
  default     = null
}

variable "cloudtrail_kms_key_administrator_iam_arns" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If you are aggregating CloudTrail logs and creating the CMK in this account (e.g., if this is the logs account), you MUST specify at least one IAM user (or other IAM ARN) that will be given administrator permissions for CMK, including the ability to change who can access this CMK and the extended log data it protects. If you are aggregating CloudTrail logs in another AWS account and the CMK already exists (e.g., if this is the stage or prod account), set this parameter to an empty list."
  type        = list(string)
  # example = ["arn:aws:iam::<aws-account-id>:user/<iam-user-name>"]
  default = []
}

variable "cloudtrail_kms_key_user_iam_arns" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If you are aggregating CloudTrail logs and creating the CMK in this account (e.g., this is the logs account), you MUST specify at least one IAM user (or other IAM ARN) that will be given user access to this CMK, which will allow this user to read CloudTrail Logs. If you are aggregating CloudTrail logs in another AWS account and the CMK already exists, set this parameter to an empty list (e.g., if this is the stage or prod account)."
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
  description = "Set to false to create an S3 bucket of name var.cloudtrail_s3_bucket_name in this account for storing CloudTrail logs (e.g., if this is the logs account). Set to true to assume the bucket specified in var.cloudtrail_s3_bucket_name already exists in another AWS account (e.g., if this is the stage or prod account and var.cloudtrail_s3_bucket_name is the name of a bucket in the logs account)."
  type        = bool
  default     = true
}

variable "cloudtrail_external_aws_account_ids_with_write_access" {
  description = "Provide a list of AWS account IDs that will be allowed to send CloudTrail logs to this account. This is only required if you are aggregating CloudTrail logs in this account (e.g., this is the logs account) from other accounts."
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
  description = "The name of the KMS CMK to use by default for encrypting EBS volumes, if var.enable_encryption and var.use_existing_kms_keys are enabled. The name must match the name given the var.kms_customer_master_keys variable."
  type        = string
  default     = ""
}

variable "ebs_opt_in_regions" {
  description = "Configures EBS encryption defaults in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), EBS encryption will be enabled on all regions enabled on the account. Use this list to provide an alternate region list for testing purposes."
  type        = list(string)
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL SERVICE LINKED ROLES PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "service_linked_roles" {
  description = "Create service-linked roles for this set of services. You should pass in the URLs of the services, but without the protocol (e.g., http://) in front: e.g., use elasticbeanstalk.amazonaws.com for Elastic Beanstalk or es.amazonaws.com for Amazon Elasticsearch. Service-linked roles are predefined by the service, can typically only be assumed by that service, and include all the permissions that the service requires to call other AWS services on your behalf. You can typically only create one such role per AWS account, which is why this parameter exists in the account baseline. See https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_aws-services-that-work-with-iam.html for the list of services that support service-linked roles."
  type        = set(string)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL IAM ACCESS ANALYZER PARAMETERS
# These variables have defaults, but may be overridden by the operator.
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
  default     = "baseline_app-iam_access_analyzer"
}

variable "iam_access_analyzer_opt_in_regions" {
  description = "Enables IAM Access Analyzer defaults in the specified regions. Note that the region must be enabled on your AWS account. Regions that are not enabled are automatically filtered from this list. When null (default), IAM Access Analyzer will be enabled on all regions enabled on the account. Use this list to provide an alternate region list for testing purposes"
  type        = list(string)
  default     = null
}
