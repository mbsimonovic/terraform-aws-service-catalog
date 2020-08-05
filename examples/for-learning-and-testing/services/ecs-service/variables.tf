# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "ecs_cluster_arn" {
  description = "The ARN of the cluster to which the ecs service should be deployed"
  type        = string
}

variable "ecs_instance_security_group_id" {
  description = "The ID of the security group that the ECS cluster module applied to all EC2 container instances"
  type        = string
}

variable "domain_name" {
  description = "The domain name to request a certificate for and to associate with the load balancer's https listener"
  type        = string
}

variable "hosted_zone_id" {
  description = "The ID of the hosted zone in which to write DNS records"
  type        = string
}

#---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "ecs_node_port_mappings" {
  description = "A map of ports used by the Docker containers on an ECS Node. The key should be the container port and the value should be what host port to map it to."
  type        = map(number)
  default = {
    "80" = 80
  }
}

variable "service_name" {
  description = "The name of the ECS service (e.g. my-service-stage)"
  type        = string
  default     = "test-ecs-service"
}

variable "desired_number_of_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster"
  type        = number
  default     = 1
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


