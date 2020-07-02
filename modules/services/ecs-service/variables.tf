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
{{- if .ConfigureCanaryDeployment }}

variable "desired_number_of_canary_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster for a canary deployment. Typically, only 0 or 1 should be used."
  type        = number
}
{{- end }}

{{- if .IncludeAutoScalingExample }}

variable "min_number_of_tasks" {
  description = "The minimum number of instances of the ECS Service to run. Auto scaling will never scale in below this number."
  type        = number
}

variable "max_number_of_tasks" {
  description = "The maximum number of instances of the ECS Service to run. Auto scaling will never scale out above this number."
  type        = number
}
{{- end }}

variable "image" {
  description = "The Docker image to run (e.g. gruntwork/frontend-service)"
  type        = string
}

variable "image_version" {
  description = "Which version (AKA tag) of the var.image Docker image to deploy (e.g. 0.57)"
  type        = string
}
{{- if .ConfigureCanaryDeployment }}

variable "canary_version" {
  description = "Which version of the ECS Service Docker container to deploy as a canary (e.g. 0.57)"
  type        = string
}
{{- end }}

variable "cpu" {
  description = "The number of CPU units to allocate to the ECS Service."
  type        = number
}

variable "memory" {
  description = "How much memory, in MB, to give the ECS Service."
  type        = number
}

variable "vpc_name" {
  description = "The name of the VPC in which all the resources should be deployed (e.g. stage, prod)"
  type        = string
}

variable "terraform_state_aws_region" {
  description = "The AWS region of the S3 bucket used to store Terraform remote state"
  type        = string
}

variable "terraform_state_s3_bucket" {
  description = "The name of the S3 bucket used to store Terraform remote state"
  type        = string
}

variable "vpc_env_var_name" {
  description = "The name of the environment variable to pass to the ECS Task that will contain the name of the current VPC (e.g. RACK_ENV, VPC_NAME)"
  type        = string
}

variable "ecs_node_port_mappings" {
  description = "A map of ports used by the Docker containers on an ECS Node. The key should be the container port and the value should be what host port to map it to."
  type = map(number)
}

{{- if .InstallCloudWatchMonitoring }}

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
{{- end }}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

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

{{- if .IncludeDatabaseUrl }}

variable "db_remote_state_path" {
  description = "The path to the DB's remote state. This path does not need to include the region or VPC name. Example: data-stores/rds/terraform.tfstate."
  type        = string
  default = "data-stores/rds/terraform.tfstate"
}

variable "db_url_env_var_name" {
  description = "The name of the env var which will contain the DB's URL."
  type        = string
  default = "DB_URL"
}
{{- end }}

{{- if .UseCustomDockerRunCommand }}

variable "custom_docker_command" {
  description = "A custom Docker command to execute when running the Docker image. Specify as a list of strings. See https://goo.gl/2BOFwp for docs on the 'command' property."
  type = list(string)
  default = []
}
{{- end }}

variable "extra_env_vars" {
  description = "A map of environment variable name to environment variable value that should be made available to the Docker container. Note, you MUST set var.num_extra_env_vars when setting this variable."
  type = map(string)
  default = {}
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

variable "terraform_state_kms_master_key" {
  description = "Path base name of the kms master key to use. This should reflect what you have in your infrastructure-live folder."
  type = string
  default = "kms-master-key"
}
