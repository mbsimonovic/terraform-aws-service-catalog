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
