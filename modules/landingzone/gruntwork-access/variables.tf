# ------------------- -------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "grant_security_account_access" {
  description = "Set to true to grant your security account, with the account ID specified in var.security_account_id, access to the IAM role. This is required for deploying a Reference Architecture."
  type        = bool
}

variable "security_account_id" {
  description = "The ID of your security account (where IAM users are defined). Required for deploying a Reference Architecture, as the Gruntwork team deploys an EC2 instance in the security account, and that instance assumes this IAM role to get access to all the other child accounts and bootstrap the deployment process."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "iam_role_name" {
  description = "The name to use for the IAM role"
  type        = string
  default     = "GruntworkAccountAccessRole"
}

variable "managed_policy_name" {
  description = "The name of the AWS Managed Policy to attach to the IAM role. To deploy a Reference Architecture, the Gruntwork team needs AdministratorAccess, so this is the default."
  type        = string
  default     = "AdministratorAccess"
}

variable "gruntwork_aws_account_id" {
  description = "The ID of the AWS account that will be allowed to assume the IAM role."
  type        = string
  # This is the ID of the Gruntwork "customer-access" AWS account
  default = "583800379690"
}

variable "require_mfa" {
  description = "If set to true, require MFA to assume the IAM role from the Gruntwork account."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}