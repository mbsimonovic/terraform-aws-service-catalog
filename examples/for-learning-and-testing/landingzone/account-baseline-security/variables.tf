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
# Modify the following variables to configure the administrator for the default KMS CMK in the account
# ---------------------------------------------------------------------------------------------------------------------

variable "kms_cmk_administrator_iam_arns" {
  description = "The ARNs of IAM users who should have admin access to the account default KMS key that is created by this example module."
  type        = list(string)
  default     = ["arn:aws:iam::123456789012:user/acme-admin"]
}
