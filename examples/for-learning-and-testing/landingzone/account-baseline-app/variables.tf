# ---------------------------------------------------------------------------------------------------------------------
# EXAMPLE PARAMETERS
# These variables must be passed in by the operator. In a real-world usage, some of these variables might not be needed
# and you can instead inline the values directly in main.tf.
# ---------------------------------------------------------------------------------------------------------------------

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account (e.g., if this is the logs account) or the name of a bucket in another AWS account where logs should be sent (e.g., if this is the stage or prod account and you're specifying the name of a bucket in the logs account)."
  type        = string
}

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. This could be a bucket in this AWS account (e.g., if this is the logs account) or the name of a bucket in another AWS account where Config items should be sent (e.g., if this is the stage or prod account and you're specifying the name of a bucket in the logs account)."
  type        = string
}

variable "cloudtrail_kms_key_administrator_iam_arns" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If you are aggregating CloudTrail logs and creating the CMK in this account (e.g., if this is the logs account), you MUST specify at least one IAM user (or other IAM ARN) that will be given administrator permissions for CMK, including the ability to change who can access this CMK and the extended log data it protects. If you are aggregating CloudTrail logs in another AWS account and the CMK already exists (e.g., if this is the stage or prod account), set this parameter to an empty list."
  type        = list(string)
  # example = ["arn:aws:iam::<aws-account-id>:user/<iam-user-name>"]
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL EXAMPLE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
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

variable "config_should_create_s3_bucket" {
  description = "Set to true to create an S3 bucket of name var.config_s3_bucket_name in this account for storing AWS Config data (e.g., if this is the logs account). Set to false to assume the bucket specified in var.config_s3_bucket_name already exists in another AWS account (e.g., if this is the stage or prod account and var.config_s3_bucket_name is the name of a bucket in the logs account)."
  type        = bool
  default     = false
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

variable "cloudtrail_s3_bucket_already_exists" {
  description = "Set to false to create an S3 bucket of name var.cloudtrail_s3_bucket_name in this account for storing CloudTrail logs (e.g., if this is the logs account). Set to true to assume the bucket specified in var.cloudtrail_s3_bucket_name already exists in another AWS account (e.g., if this is the stage or prod account and var.cloudtrail_s3_bucket_name is the name of a bucket in the logs account)."
  type        = bool
  default     = true
}

variable "cloudtrail_kms_key_user_iam_arns" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If you are aggregating CloudTrail logs and creating the CMK in this account (e.g., this is the logs account), you MUST specify at least one IAM user (or other IAM ARN) that will be given user access to this CMK, which will allow this user to read CloudTrail Logs. If you are aggregating CloudTrail logs in another AWS account and the CMK already exists, set this parameter to an empty list (e.g., if this is the stage or prod account)."
  type        = list(string)
  # example = ["arn:aws:iam::<aws-account-id>:user/<iam-user-name>"]
  default = []
}

variable "cloudtrail_external_aws_account_ids_with_write_access" {
  description = "Provide a list of AWS account IDs that will be allowed to send CloudTrail logs to this account. This is only required if you are aggregating CloudTrail logs in this account (e.g., this is the logs account) from other accounts."
  type        = list(string)
  default     = []
}

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists (e.g., if this is the stage or prod account and you want to use a CMK that already exists in the logs account), set this to the ARN of that CMK. Otherwise (e.g., if this is the logs account), set this to null, and a new CMK will be created."
  type        = string
  default     = null
}

variable "cloudtrail_cloudwatch_logs_group_name" {
  description = "Specify the name of the CloudWatch Logs group to publish the CloudTrail logs to. This log group exists in the current account. Set this value to `null` to avoid publishing the trail logs to the logs group. The recommended configuration for CloudTrail is (a) for each child account to aggregate its logs in an S3 bucket in a single central account, such as a logs account and (b) to also store 14 days work of logs in CloudWatch in the child account itself for local debugging."
  type        = string
  default     = "cloudtrail-logs"
}

# ---------------------------------------------------------------------------------------------------------------------
#  Modify the following variables to allow users from the security account to assume IAM roles in this account
# ---------------------------------------------------------------------------------------------------------------------

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
  description = "A list of IAM ARNs from other AWS accounts that will be allowed read access to the logs in CloudTrail, AWS Config, and CloudWatch in this account."
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

variable "dev_permitted_services" {
  description = "A list of AWS services for which the developers from the accounts in var.allow_dev_access_from_other_account_arns will receive full permissions. See https://goo.gl/ZyoHlz to find the IAM Service name. For example, to grant developers access only to EC2 and Amazon Machine Learning, use the value [\"ec2\",\"machinelearning\"]. Do NOT add iam to the list of services, or that will grant Developers de facto admin access."
  type        = list(string)
  default     = []
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
  # - cmk_user_iam_arns                     [list(string)] : A list of IAM ARNs for users who should be given
  #                                                          permissions to use this CMK (e.g.
  #                                                          arn:aws:iam::<aws-account-id>:user/<iam-user-arn>).
  # - cmk_external_user_iam_arns            [list(string)] : A list of IAM ARNs for users from external AWS accounts
  #                                                          who should be given permissions to use this CMK (e.g.
  #                                                          arn:aws:iam::<aws-account-id>:root).
  # - cmk_service_principals                [list(object[ServicePrincipal])] : A list of Service Principals that should be given
  #                                                          permissions to use this CMK (e.g. s3.amazonaws.com). See
  #                                                          below for the structure of the object that should be passed
  #                                                          in.
  #
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
  #
  #
  # Example:
  # customer_master_keys = {
  #   cmk-stage = {
  #     region                                = "us-west-1"
  #     cmk_administrator_iam_arns            = ["arn:aws:iam::0000000000:user/admin"]
  #     cmk_user_iam_arns                     = ["arn:aws:iam::0000000000:user/dev"]
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
  #     cmk_user_iam_arns                     = ["arn:aws:iam::0000000000:user/dev"]
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
