# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "service_name" {
  description = "The name of the ECS service (e.g. my-service-stage)"
  type        = string
}

variable "desired_number_of_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster"
  type        = number
  default     = 1
}

variable "ecs_node_port_mappings" {
  description = "A map of ports used by the Docker containers on an ECS Node. The key should be the container port and the value should be what host port to map it to."
  type        = map(number)
}

variable "ecs_cluster_arn" {
  description = "The ARN of the cluster to which the ecs service should be deployed"
  type        = string
}

variable "container_definitions" {
  description = "Map of names to container definitions to use for the ECS task. Each entry corresponds to a different ECS container definition. The key corresponds to a user defined name for the container definition"
  type        = any
}
#---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "high_cpu_utilization_threshold" {
  description = "Trigger an alarm if the ECS Service has a CPU utilization percentage above this threshold"
  type        = number
  default     = 90
}

variable "high_cpu_utilization_period" {
  description = "The period, in seconds, over which to measure the CPU utilization percentage"
  type        = number
  default     = 300
}

variable "high_memory_utilization_threshold" {
  description = "Trigger an alarm if the ECS Service has a memory utilization percentage above this threshold"
  type        = number
  default     = 90
}

variable "high_memory_utilization_period" {
  description = "The period, in seconds, over which to measure the memory utilization percentage"
  type        = number
  default     = 300
}

variable "min_number_of_tasks" {
  description = "The minimum number of instances of the ECS Service to run. Auto scaling will never scale in below this number."
  type        = number
  default     = 1
}

variable "max_number_of_tasks" {
  description = "The maximum number of instances of the ECS Service to run. Auto scaling will never scale out above this number."
  type        = number
  default     = 3
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


