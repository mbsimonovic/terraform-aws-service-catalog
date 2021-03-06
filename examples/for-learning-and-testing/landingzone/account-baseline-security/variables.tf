# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name_prefix" {
  description = "The name used to prefix AWS Config and CloudTrail resources, including the S3 bucket names and SNS topics used for each."
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

variable "config_s3_bucket_name" {
  description = "The name of the S3 Bucket where Config items will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where Config items should be sent. We recommend setting this to the name of an S3 bucket in a separate logs account."
  type        = string
}

variable "config_central_account_id" {
  description = "If the S3 bucket and SNS topics used for AWS Config live in a different AWS account, set this variable to the ID of that account. If the S3 bucket and SNS topics live in this account, set this variable to null. We recommend setting this to the ID of a separate logs account."
  type        = string
}

variable "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 Bucket where CloudTrail logs will be stored. This could be a bucket in this AWS account or the name of a bucket in another AWS account where logs should be sent. We recommend setting this to the name of a bucket in a separate logs account."
  type        = string
}

variable "cloudtrail_kms_key_arn" {
  description = "All CloudTrail Logs will be encrypted with a KMS CMK (Customer Master Key) that governs access to write API calls older than 7 days and all read API calls. If that CMK already exists, set this to the ARN of that CMK. Otherwise, set this to null, and a new CMK will be created. We recommend setting this to the ARN of a CMK that already exists in a separate logs account."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

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
  description = "If set to ACCOUNT, the analyzer will only be scanning resources in the current AWS account it's in, for the regions that it's enabled in. If set to ORGANIZATION and this is the management account for the organization, then the analyzer will scan resource policies across the organization."
  type        = string
  default     = "ACCOUNT"
}

variable "iam_access_analyzer_name" {
  description = "The name of the IAM Access Analyzer module"
  type        = string
  default     = "baseline_security-iam_access_analyzer"
}
