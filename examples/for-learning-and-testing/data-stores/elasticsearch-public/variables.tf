# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this example terraform module.
# ---------------------------------------------------------------------------------------------------------------------

variable "domain_name" {
  description = "The name of the Elasticsearch cluster. It must be unique to your account and region, start with a lowercase letter, contain between 3 and 28 characters, and contain only lowercase letters a-z, the numbers 0-9, and the hyphen (-)."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables are set with defaults to make running the example easier.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created."
  type        = string
  default     = "eu-west-1"
}

variable "enable_encryption_at_rest" {
  description = "When true, the Elasticsearch domain storage will be encrypted at rest using the aws/es service KMS key. It defaults to false here for testing purposes and because setting it to true is not available on the free tier. In production, you should set this to true."
  type        = bool
  default     = false
}
