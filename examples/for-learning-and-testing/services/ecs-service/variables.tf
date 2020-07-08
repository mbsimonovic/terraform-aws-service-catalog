# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "aws_account_id" {
  description = "The ID of the AWS Account in which to create resources."
  type        = string
}

variable "service_name" {
  description = "The name of the ECS service (e.g. my-service-stage)"
  type        = string
}

variable "desired_number_of_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster"
  type        = number
}

variable "desired_number_of_canary_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster for a canary deployment. Typically, only 0 or 1 should be used."
  type        = number
}

variable "min_number_of_tasks" {
  description = "The minimum number of instances of the ECS Service to run. Auto scaling will never scale in below this number."
  type        = number
}

variable "max_number_of_tasks" {
  description = "The maximum number of instances of the ECS Service to run. Auto scaling will never scale out above this number."
  type        = number
}

variable "image" {
  description = "The Docker image to run (e.g. gruntwork/frontend-service)"
  type        = string
}

variable "image_version" {
  description = "Which version (AKA tag) of the var.image Docker image to deploy (e.g. 0.57)"
  type        = string
}

variable "canary_version" {
  description = "Which version of the ECS Service Docker container to deploy as a canary (e.g. 0.57)"
  type        = string
}

variable "cpu" {
  description = "The number of CPU units to allocate to the ECS Service."
  type        = number
}

variable "memory" {
  description = "How much memory, in MB, to give the ECS Service."
  type        = number
}

variable "vpc_env_var_name" {
  description = "The name of the environment variable to pass to the ECS Task that will contain the name of the current VPC (e.g. RACK_ENV, VPC_NAME)"
  type        = string
}

variable "ecs_node_port_mappings" {
  description = "A map of ports used by the Docker containers on an ECS Node. The key should be the container port and the value should be what host port to map it to."
  type        = map(number)
}

variable "high_cpu_utilization_threshold" {
  description = "Trigger an alarm if the ECS Service has a CPU utilization percentage above this threshold"
  type        = number
}

variable "high_cpu_utilization_period" {
  description = "The period, in seconds, over which to measure the CPU utilization percentage"
  type        = number
}

variable "high_memory_utilization_threshold" {
  description = "Trigger an alarm if the ECS Service has a memory utilization percentage above this threshold"
  type        = number
}

variable "high_memory_utilization_period" {
  description = "The period, in seconds, over which to measure the memory utilization percentage"
  type        = number
}

variable "alarm_sns_topic_arn" {
  description = "The ARN of the SNS topic to write alarm events to"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "The ARN of the cluster to which the ecs service should be deployed"
  type        = string
}

variable "kms_master_key_arn" {
  description = "The ARN of the master KMS key"
  type        = string
}

variable "db_primary_endpoint" {
  description = "The primary db endpoint"
  type        = string
}

variable "ecs_instance_security_group_id" {
  description = "The ID of the security group that should be applied to ecs service instances"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------
variable "use_custom_docker_run_command" {
  description = "Set this to true if you want to pass a custom docker run command. If you set this to true, you must supply var.custom_docker_command"
  type        = bool
  default     = false
}

variable "custom_docker_command" {
  description = "If var.use_custom_docker_run_command is set to true, set this variable to the custom docker run command you want to provide"
  type        = string
  default     = null
}

variable "use_auto_scaling" {
  description = "Whether or not to enable auto scaling for the ecs service"
  type        = bool
  default     = false
}

variable "desired_number_of_canary_tasks_to_run" {
  description = "The number of tasks that should use the canary image and tag"
  type        = number
  default     = 0
}

variable "ecs_cluster_name" {
  description = "The name of the ecs cluster to deploy the ecs service onto"
  type        = string
  default     = null
}

variable "deployment_maximum_percent" {
  description = "The upper limit, as a percentage of var.desired_number_of_tasks, of the number of running tasks that can be running in a service during a deployment. Setting this to more than 100 means that during deployment, ECS will deploy new instances of a Task before undeploying the old ones."
  type        = number
  default     = 200
}

variable "deployment_minimum_healthy_percent" {
  description = "The lower limit, as a percentage of var.desired_number_of_tasks, of the number of running tasks that must remain running and healthy in a service during a deployment. Setting this to less than 100 means that during deployment, ECS may undeploy old instances of a Task before deploying new ones."
  type        = number
  default     = 100
}

variable "aws_region_env_var_name" {
  description = "The name of the environment variable that specifies the current AWS region."
  type        = string
  default     = "AWS_REGION"
}

variable "db_remote_state_path" {
  description = "The path to the DB's remote state. This path does not need to include the region or VPC name. Example: data-stores/rds/terraform.tfstate."
  type        = string
  default     = "data-stores/rds/terraform.tfstate"
}

variable "db_url_env_var_name" {
  description = "The name of the env var which will contain the DB's URL."
  type        = string
  default     = "DB_URL"
}

variable "extra_env_vars" {
  description = "A map of environment variable name to environment variable value that should be made available to the Docker container. Note, you MUST set var.num_extra_env_vars when setting this variable."
  type        = map(string)
  default     = {}
}

variable "num_extra_env_vars" {
  description = "The number of entries in var.extra_env_vars. We should be able to compute this automatically, but can't due to a Terraform bug: https://github.com/hashicorp/terraform/issues/3888"
  type        = number
  default     = 0
}

variable "force_destroy" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
}

