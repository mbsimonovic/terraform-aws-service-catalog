# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "container_image" {
  description = "Docker image (repo and tag) to use for the ECS task. Should contain the infrastructure-deploy-script for the pipeline to work. Refer to the Dockerfile in /modules/ecs-deploy-runner/docker/Dockerfile for a sample container you can use."
  type = object({
    repo = string
    tag  = string
  })
}

variable "repository" {
  description = "Git repository where source code is located."
  type        = string
}

variable "ssh_private_key_secrets_manager_arn" {
  description = "ARN of the AWS Secrets Manager entry to use for sourcing the SSH private key for cloning repositories. Set to null if you are only using public repos."
  type        = string
}

variable "approved_apply_refs" {
  description = "A list of Git Refs (branch or tag) that are approved for running apply on. Any git ref that does not match this list will not be allowed to run `apply` or `apply-all`. This is useful for protecting against internal threats where users have access to the CI script and bypass the approval flow by commiting a new CI flow on their branch. Set to null to allow all refs to apply."
  type        = list(string)
  # Example:
  # approved_apply_refs = ["master", "dev", "stage", "prod"]
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------
#
variable "aws_region" {
  description = "The AWS region for the deploy runner."
  type        = string
  default     = "eu-west-1"
}


variable "name" {
  description = "Name of this instance of the deploy runner stack. Used to namespace all resources."
  type        = string
  default     = "ecs-deploy-runner"
}

variable "iam_users" {
  description = "List of AWS IAM usernames that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
}

variable "iam_groups" {
  description = "List of AWS IAM groups that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
}

variable "iam_roles" {
  description = "List of AWS IAM roles that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
}

variable "permitted_services" {
  description = "A list of AWS services for which the Deploy Runner ECS Task will receive full permissions. For example, to grant the deploy runner access only to EC2 and Amazon Machine Learning, use the value [\"ec2\",\"machinelearning\"]."
  type        = list(string)
  default     = []
}
