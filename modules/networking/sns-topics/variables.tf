#---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the SNS topic"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "display_name" {
  description = "The display name of the SNS topic"
  type        = string
  default     = ""
}

variable "allow_publish_accounts" {
  description = "A list of IAM ARNs that will be given the rights to publish to the SNS topic."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:role/jenkins"
  # ]
}

variable "allow_publish_services" {
  description = "A list of AWS services that will be given the rights to publish to the SNS topic."
  type        = list(string)
  default     = []
  # Example :
  # allow_publish_services = [
  #   "events.amazonaws.com",
  #   "cloudwatch.amazonaws.com"
  # ]
}

variable "allow_subscribe_accounts" {
  description = "A list of IAM ARNs that will be given the rights to subscribe to the SNS topic."
  type        = list(string)
  default     = []
  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:user/jdoe"
  # ]
}

variable "allow_subscribe_protocols" {
  description = "A list of protocols that can be used to subscribe to the SNS topic."
  type        = list(string)
  default = [
    "http",
    "https",
    "email",
    "email-json",
    "sms",
    "sqs",
    "application",
    "lambda"
  ]
}

variable "slack_webhook_url" {
  description = "Send topic notifications to this Slack Webhook URL (e.g., https://hooks.slack.com/services/FOO/BAR/BAZ)."
  type        = string
  default     = null
}

variable "create_resources" {
  description = "Set to false to have this module create no resources. This weird parameter exists solely because Terraform does not support conditional modules. Therefore, this is a hack to allow you to conditionally decide if the resources should be created or not."
  type        = bool
  default     = true
}

variable "kms_master_key_id" {
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SNS or a custom CMK"
  type        = string
  default     = "alias/aws/sns"
}
