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
  description = "Set to true to create an S3 bucket of name var.config_s3_bucket_name in this account for storing AWS Config data (e.g., if this is the logs account). Set to false to assume the bucket specified in var.config_s3_bucket_name already exists in another AWS account (e.g., if this is the stage or prod account and var.config_s3_bucket_name is the name of a bucket in the logs account)."
  type        = bool
  default     = false
}

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. Can be in the same account or in another account."
  type        = string
  default     = null
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

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account (e.g., if this is the stage or prod account, set this to the ID of the logs account). If the S3 bucket and SNS topics live in this account (e.g., this is the logs account), set this variable to null."
  type        = string
  default     = null
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL CROSS ACCOUNT IAM ROLES PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "should_require_mfa" {
  description = "Should we require that all IAM Users use Multi-Factor Authentication for both AWS API calls and the AWS Web Console? (true or false)"
  type        = bool
  default     = true
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
  # - cmk_administrator_iam_arns            [list(string)] : A list of IAM ARNs for users who should be given
  #                                                          administrator access to this CMK (e.g.
  #                                                          arn:aws:iam::<aws-account-id>:user/<iam-user-arn>).
  # - cmk_user_iam_arns                     [list(object[CMKUser])] : A list of IAM ARNs for users who should be given
  #                                                          permissions to use this CMK (e.g.
  #                                                          arn:aws:iam::<aws-account-id>:user/<iam-user-arn>).
  # - cmk_external_user_iam_arns            [list(string)] : A list of IAM ARNs for users from external AWS accounts
  #                                                          who should be given permissions to use this CMK (e.g.
  #                                                          arn:aws:iam::<aws-account-id>:root).
  # - cmk_service_principals                [list(object[ServicePrincipal])] : A list of Service Principals that should be given
  #                                                          permissions to use this CMK (e.g. s3.amazonaws.com). See
  #                                                          below for the structure of the object that should be passed
  #                                                          in.

  # - allow_manage_key_permissions_with_iam [bool]         : If true, both the CMK's Key Policy and IAM Policies
  #                                                          (permissions) can be used to grant permissions on the CMK.
  #                                                          If false, only the CMK's Key Policy can be used to grant
  #                                                          permissions on the CMK. False is more secure (and
  #                                                          generally preferred), but true is more flexible and
  #                                                          convenient.
  # - region                  [string]      : The region (e.g., us-west-2) where the key should be created. If null or
  #                                           omitted, the key will be created in all enabled regions. Any keys
  #                                           targeting an opted out region or invalid region string will show up in the
  #                                           invalid_cmk_inputs output.
  # - deletion_window_in_days [number]      : The number of days to keep this KMS Master Key around after it has been
  #                                           marked for deletion.
  # - tags                    [map(string)] : A map of tags to apply to the KMS Key to be created. In this map
  #                                           variable, the key is the tag name and the value  is the tag value. Note
  #                                           that this map is merged with var.global_tags, and can be used to override
  #                                           tags specified in that variable.
  # - enable_key_rotation     [bool]        : Whether or not to enable automatic annual rotation of the KMS key.
  # - spec                    [string]      : Specifies whether the key contains a symmetric key or an asymmetric key
  #                                           pair and the encryption algorithms or signing algorithms that the key
  #                                           supports. Valid values: SYMMETRIC_DEFAULT, RSA_2048, RSA_3072, RSA_4096,
  #                                           ECC_NIST_P256, ECC_NIST_P384, ECC_NIST_P521, or ECC_SECG_P256K1.
  # Structure of ServicePrincipal object:
  # - name          [string]                   : The name of the service principal (e.g.: s3.amazonaws.com).
  # - actions       [list(string)]             : The list of actions that the given service principal is allowed to
  #                                              perform (e.g. ["kms:DescribeKey", "kms:GenerateDataKey"]).
  # - conditions    [list(object[Condition])]  : (Optional) List of conditions to apply to the permissions for the service
  #                                              principal. Use this to apply conditions on the permissions for
  #                                              accessing the KMS key (e.g., only allow access for certain encryption
  #                                              contexts). The condition object accepts the same fields as the condition
  #                                              block on the IAM policy document (See
  #                                              https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html#condition).
  # Structure of CMKUser object:
  # - name          [list(string)]             : The list of names of the AWS principal (e.g.: arn:aws:iam::0000000000:user/dev).
  # - conditions    [list(object[Condition])]  : (Optional) List of conditions to apply to the permissions for the CMK User
  #                                              Use this to apply conditions on the permissions for accessing the KMS key
  #                                              (e.g., only allow access for certain encryption contexts).
  #                                              The condition object accepts the same fields as the condition
  #                                              block on the IAM policy document (See
  #                                              https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html#condition).
  #
  # Example:
  # customer_master_keys = {
  #   cmk-stage = {
  #     region                                = "us-west-1"
  #     cmk_administrator_iam_arns            = ["arn:aws:iam::0000000000:user/admin"]
  #     cmk_user_iam_arns                     = [
  #       {
  #         name = ["arn:aws:iam::0000000000:user/dev"]
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
  #     region                                = "us-west-1"
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

# ---------------------------------------------------------------------------------------------------------------------
# VPC PARAMETERS
# These parameters configure the management VPC that is included with the baseline configuration.
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_name" {
  description = "The name of the VPC. Defaults to mgmt."
  type        = string
  default     = "mgmt"
}

variable "cidr_block" {
  description = "The IP address range of the VPC in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27. Examples include '10.100.0.0/16', '10.200.0.0/16', etc."
  type        = string
  default     = "172.31.80.0/20"
}

variable "num_nat_gateways" {
  description = "The number of NAT Gateways to launch for this VPC. The management VPC defaults to 1 NAT Gateway to save on cost, but to increase redundancy, you can adjust this to add additional NAT Gateways."
  type        = number
  default     = 1
}

variable "num_availability_zones" {
  description = "How many AWS Availability Zones (AZs) to use. One subnet of each type (public, private app) will be created in each AZ. Note that this must be less than or equal to the total number of AZs in a region. A value of null means all AZs should be used. For example, if you specify 3 in a region with 5 AZs, subnets will be created in just 3 AZs instead of all 5. Defaults to 3."
  type        = number
  default     = 3
}

variable "availability_zone_exclude_names" {
  description = "List of excluded Availability Zone names."
  type        = list(string)
  default     = []
}

variable "availability_zone_exclude_ids" {
  description = "List of excluded Availability Zone IDs."
  type        = list(string)
  default     = []
}

variable "availability_zone_state" {
  description = "Allows to filter list of Availability Zones based on their current state. Can be either \"available\", \"information\", \"impaired\" or \"unavailable\". By default the list includes a complete set of Availability Zones to which the underlying AWS account has access, regardless of their state."
  type        = string
  default     = null
}

variable "public_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 4
}

variable "private_subnet_bits" {
  description = "Takes the CIDR prefix and adds these many bits to it for calculating subnet ranges.  MAKE SURE if you change this you also change the CIDR spacing or you may hit errors.  See cidrsubnet interpolation in terraform config for more information."
  type        = number
  default     = 4
}

variable "subnet_spacing" {
  description = "The amount of spacing between the different subnet types"
  type        = number
  default     = 8
}

variable "public_subnet_cidr_blocks" {
  description = "A map listing the specific CIDR blocks desired for each public subnet. The key must be in the form AZ-0, AZ-1, ... AZ-n where n is the number of Availability Zones. If left blank, we will compute a reasonable CIDR block for each subnet."
  type        = map(string)
  default     = {}
  # Example:
  # default = {
  #    AZ-0 = "10.226.20.0/24"
  #    AZ-1 = "10.226.21.0/24"
  #    AZ-2 = "10.226.22.0/24"
  # }
}

variable "private_subnet_cidr_blocks" {
  description = "A map listing the specific CIDR blocks desired for each private subnet. The key must be in the form AZ-0, AZ-1, ... AZ-n where n is the number of Availability Zones. If left blank, we will compute a reasonable CIDR block for each subnet."
  type        = map(string)
  default     = {}
  # Example:
  # default = {
  #    AZ-0 = "10.226.30.0/24"
  #    AZ-1 = "10.226.31.0/24"
  #    AZ-2 = "10.226.32.0/24"
  # }
}

variable "custom_tags" {
  description = "A map of tags to apply to the VPC, Subnets, Route Tables, and Internet Gateway. The key is the tag name and the value is the tag value. Note that the tag 'Name' is automatically added by this module but may be optionally overwritten by this variable."
  type        = map(string)
  default     = {}
}

variable "vpc_custom_tags" {
  description = "A map of tags to apply just to the VPC itself, but not any of the other resources. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "public_subnet_custom_tags" {
  description = "A map of tags to apply to the public Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "private_subnet_custom_tags" {
  description = "A map of tags to apply to the private Subnet, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}

variable "nat_gateway_custom_tags" {
  description = "A map of tags to apply to the NAT gateways, on top of the custom_tags. The key is the tag name and the value is the tag value. Note that tags defined here will override tags defined as custom_tags in case of conflict."
  type        = map(string)
  default     = {}
}
