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

variable "enable_versioning" {
  description = "Set to true to enable versioning for this bucket. If enabled, instead of overriding objects, the S3 bucket will always create a new version of each object, so all the old values are retained."
  type        = bool
  default     = true
}

variable "mfa_delete" {
  description = "Enable MFA delete for either 'Change the versioning state of your bucket' or 'Permanently delete an object version'. This cannot be used to toggle this setting but is available to allow managed buckets to reflect the state in AWS. Only used if enable_versioning is true. CIS v1.4 requires this variable to be true. If you do not wish to be CIS-compliant, you can set it to false."
  type        = bool
  default     = false
}
