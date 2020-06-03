variable "vpc_id" {
  description = "ID of the VPC where the ECS task and Lambda function should run."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of IDs of private subnets that can be used for running the ECS task and Lambda function."
  type        = list(string)
}

variable "approved_apply_refs" {
  description = "A list of Git Refs (branch or tag) that are approved for running apply on. Any git ref that does not match this list will not be allowed to run `apply` or `apply-all`. This is useful for protecting against internal threats where users have access to the CI script and bypass the approval flow by commiting a new CI flow on their branch. Set to null to allow all refs to apply."
  type        = list(string)
}

variable "container_images" {
  description = "Map of names to docker image (repo and tag) to use for the ECS task. Each entry corresponds to a different ECS task definition that can be used for infrastructure pipelines. The key corresponds to a user defined name that can be used with the invoker function to determine which task definition to use."
  type = map(object({
    # Docker container identifiers
    docker_image = string
    docker_tag   = string

    # Map of environment variable names to secret manager arns of secrets to share with the container during runtime.
    secrets_manager_arns = map(string)

    # Whether or not the particular container is the default container for the pipeline. This container is used when no
    # name is provided to the infrastructure deployer. Exactly one must be marked as the default: the behavior of which
    # container becomes the default is undefined when there are multiple.
    # If no containers are marked as default, then the invoker lambda function always requires a container name to be
    # provided.
    default = bool
  }))
}


variable "repository" {
  description = "Git repository where source code is located."
  type        = string
}

variable "name" {
  description = "Name of this instance of the deploy runner stack. Used to namespace all resources."
  type        = string
  default     = "ecs-deploy-runner"
}

variable "iam_roles" {
  description = "List of AWS IAM roles that should be given access to invoke the deploy runner."
  type        = list(string)
  default     = []
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

variable "permitted_services" {
  description = "A list of AWS services for which the Deploy Runner ECS Task will receive full permissions. For example, to grant the deploy runner access only to EC2 and Amazon Machine Learning, use the value [\"ec2\",\"machinelearning\"]."
  type        = list(string)
  default     = []
}
