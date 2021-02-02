# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------
variable "primary_bucket" {
  description = "What to name the S3 bucket. Note that S3 bucket names must be globally unique across all AWS users!"
  type        = string
}

variable "access_logging_bucket" {
  description = "The S3 bucket where access logs for this bucket should be stored. Set to null to disable access logging."
  type        = string
}

variable "replica_bucket" {
  description = "The S3 bucket that will be the replica of this bucket. Set to null to disable bucket replication."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy to."
  type        = string
  default     = "eu-central-1"
}

variable "replica_aws_region" {
  description = "The AWS region for the replica."
  type        = string
  default     = "eu-west-1"
}
