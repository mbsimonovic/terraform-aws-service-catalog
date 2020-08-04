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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL EXAMPLE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where Config items should be sent. We recommend setting this to the name of an S3 bucket in a separate logs account."
  type        = string
  default     = null
}

variable "config_should_create_s3_bucket" {
  description = "Set to true to create an S3 bucket of name var.config_s3_bucket_name in this account for storing AWS Config data. Set to false to assume the bucket specified in var.config_s3_bucket_name already exists in another AWS account. We recommend setting this to false and setting var.config_s3_bucket_name to the name off an S3 bucket that already exists in a separate logs account."
  type        = bool
  default     = false
}

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account. If the S3 bucket and SNS topics live in this account, set this variable to null. We recommend setting this to the ID of a separate logs account."
  type        = string
  default     = null
}

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where logs should be sent. We recommend setting this to the name of a bucket in a separate logs account."
  type        = string
  default     = null
}

variable "cloudtrail_s3_bucket_already_exists" {
  description = "Set to false to create an S3 bucket of name var.cloudtrail_s3_bucket_name in this account for storing CloudTrail logs. Set to true to assume the bucket specified in var.cloudtrail_s3_bucket_name already exists in another AWS account. We recommend setting this to true and setting var.cloudtrail_s3_bucket_name to the name of a bucket that already exists in a separate logs account."
  type        = bool
  default     = true
}

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists, set this to the ARN of that CMK. Otherwise, set this to null, and a new CMK will be created. We recommend setting this to the ARN of a CMK that already exists in a separate logs account."
  type        = string
  default     = null
}

variable "cloudtrail_cloudwatch_logs_group_name" {
  description = "Specify the name of the CloudWatch Logs group to publish the CloudTrail logs to. This log group exists in the current account. Set this value to `null` to avoid publishing the trail logs to the logs group. The recommended configuration for CloudTrail is (a) for each child account to aggregate its logs in an S3 bucket in a single central account, such as a logs account and (b) to also store 14 days work of logs in CloudWatch in the child account itself for local debugging."
  type        = string
  default     = "cloudtrail-logs"
}
