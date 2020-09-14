# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "eu-west-1"
}

variable "iam_role_name" {
  description = "The name to use for the IAM role"
  type        = string
  default     = "GruntworkAccountAccessRole"
}