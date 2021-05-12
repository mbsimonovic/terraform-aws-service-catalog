# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created."
  type        = string
  default     = "eu-west-1"
}

variable "name" {
  description = "The name to use for the Lambda function"
  type        = string
  default     = "lambda-example"
}

variable "sns_topic_name" {
  description = "The name of the SNS Topic to be used for alerting failures of this lambda function"
  type        = string
  default     = "lambda-example-sns-topic"
}
