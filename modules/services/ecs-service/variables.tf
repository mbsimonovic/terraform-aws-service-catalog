# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "service_name" {
  description = "The name of the ECS service (e.g. my-service-stage)"
  type        = string
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------
variable "secret_manager_arns" {
  description = "A list of ARNs for Secrets Manager secrets that the ECS execution IAM policy should be granted access to read. Note that this is different from the ECS task IAM policy. The execution policy is concerned with permissions required to run the ECS task."
  type        = list(string)
  default     = []
}

variable "alarm_sns_topic_arns" {
  description = "A list of ARNs of the SNS topic(s) to write alarm events to"
  type        = list(string)
  default     = []
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

# ---------------------------------------------------------------------------------------------------------------------
# CANARY TASK CONFIGURATION
# You can optionally run a canary task, which is helpful for testing a new release candidate
# ---------------------------------------------------------------------------------------------------------------------

variable "canary_container_definitions" {
  description = "Map of names to container definitions to use for the canary ECS task. Each entry corresponds to a different ECS container definition. The key corresponds to a user defined name for the container definition"
  type        = any
  default     = {}
}

variable "canary_version" {
  description = "Which version of the ECS Service Docker container to deploy as a canary (e.g. 0.57)"
  type        = string
  default     = null
}

variable "desired_number_of_canary_tasks" {
  description = "How many instances of the ECS Service to run across the ECS cluster for a canary deployment. Typically, only 0 or 1 should be used."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------------------------------------------------
# LOAD BALANCER CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "clb_name" {
  description = "The name of a Classic Load Balancer (CLB) to associate with this service. Containers in the service will automatically register with the CLB when booting up. Set to null if using ELBv2."
  type        = string
  default     = null
}

variable "clb_container_name" {
  description = "The name of the container, as it appears in the var.task_arn Task definition, to associate with a CLB. Currently, ECS can only associate a CLB with a single container per service. Only used if clb_name is set."
  type        = string
  default     = null
}

variable "clb_container_port" {
  description = "The port on the container in var.clb_container_name to associate with an CLB. Currently, ECS can only associate a CLB with a single container per service. Only used if clb_name is set."
  type        = number
  default     = null
}

variable "elb_target_groups" {
  description = "Configurations for ELB target groups for ALBs and NLBs that should be associated with the ECS Tasks. Each entry corresponds to a separate target group. Set to the empty object ({}) if you are not using an ALB or NLB."
  type = map(object(
    {
      # The name of the ELB Target Group that will contain the ECS Tasks.
      name = string

      # The name of the container, as it appears in the var.task_arn Task definition, to associate with the target
      # group.
      container_name = string

      # The port on the container to associate with the target group.
      container_port = number

      # The network protocol to use for routing traffic from the ELB to the Targets. Must be one of TCP, TLS, UDP, TCP_UDP, HTTP or HTTPS. Note that when using ALBs, must be HTTP or HTTPS.
      protocol = string

      # The protocol the ELB uses when performing health checks on Targets. Must be one of TCP, TLS, UDP, TCP_UDP, HTTP or HTTPS. Note that when using ALBs, must be HTTP or HTTPS.
      health_check_protocol = string
    }
  ))
  default = {}
}

variable "elb_target_group_vpc_id" {
  description = "The ID of the VPC in which to create the target group. Only used if var.elb_target_group_name is set."
  type        = string
  default     = null
}

variable "elb_target_group_deregistration_delay" {
  description = "The amount of time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds. Only used if var.elb_target_group_name is set."
  type        = number
  default     = 300
}

variable "elb_slow_start" {
  description = "The amount time for targets to warm up before the load balancer sends them a full share of requests. The range is 30-900 seconds or 0 to disable. The default value is 0 seconds. Only used if var.elb_target_group_name is set."
  type        = number
  default     = 0
}

variable "use_alb_sticky_sessions" {
  description = "If true, the ALB will use use Sticky Sessions as described at https://goo.gl/VLcNbk. Only used if var.elb_target_group_name is set. Note that this can only be true when associating with an ALB. This cannot be used with CLBs or NLBs."
  type        = bool
  default     = false
}

variable "alb_sticky_session_type" {
  description = "The type of Sticky Sessions to use. See https://goo.gl/MNwqNu for possible values. Only used if var.elb_target_group_name is set."
  type        = string
  default     = "lb_cookie"
}

variable "alb_sticky_session_cookie_duration" {
  description = "The time period, in seconds, during which requests from a client should be routed to the same Target. After this time period expires, the load balancer-generated cookie is considered stale. The acceptable range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds). Only used if var.elb_target_group_name is set."
  type        = number
  default     = 86400
}
# ---------------------------------------------------------------------------------------------------------------------
# SECURITY PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "expose_ecs_service_to_other_ecs_nodes" {
  description = "Set this to true to allow the ecs service to be accessed by other ecs nodes"
  type        = bool
  default     = false
}

variable "secrets_manager_kms_key_arn" {
  description = "The ARN of the kms key associated with secrets manager"
  type        = string
  default     = null
}

variable "ecs_instance_security_group_id" {
  description = "The ID of the security group that should be applied to ecs service instances"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH ALARMS & MONITORING PARAMETERS
# These values may optionally be overwritten by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------
variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable Cloudwatch alarms on the ecs service instances"
  type        = bool
  default     = false
}

variable "cloudwatch_log_group_name" {
  description = "The name for the Cloudwatch logs that will be generated by the ecs service"
  type        = string
  default     = null
}

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

variable "cpu" {
  description = "The number of CPU units to allocate to the ECS Service."
  type        = number
  default     = 1
}

variable "memory" {
  description = "How much memory, in MB, to give the ECS Service."
  type        = number
  default     = 500
}

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
  default     = true
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

variable "force_destroy" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# ECS DEPLOYMENT CHECK OPTIONS
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_ecs_deployment_check" {
  description = "Whether or not to enable the ECS deployment check binary to make terraform wait for the task to be deployed. See ecs_deploy_check_binaries for more details. You must install the companion binary before the check can be used. Refer to the README for more details."
  type        = bool
  default     = true
}

variable "deployment_check_timeout_seconds" {
  description = "Seconds to wait before timing out each check for verifying ECS service deployment. See ecs_deploy_check_binaries for more details."
  type        = number
  default     = 600
}

variable "deployment_check_loglevel" {
  description = "Set the logging level of the deployment check script. You can set this to `error`, `warn`, or `info`, in increasing verbosity."
  type        = string
  default     = "info"
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM ROLES AND POLICIES 
# ---------------------------------------------------------------------------------------------------------------------

variable "iam_role_exists" {
  description = "Whether or not the IAM role passed in `iam_role_name` already exists. Set to true if it exists, or false if it needs to be created. Defaults to false."
  type        = bool
  default     = false
}

variable "iam_role_name" {
  description = "The name of an IAM role that will be used by the pod to access the AWS API. If `iam_role_exists` is set to false, this role will be created. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type        = string
  default     = ""
}

variable "iam_policy" {
  description = "An object defining the policy to attach to `iam_role_name` if the IAM role is going to be created. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement. Ignored if `iam_role_arn` is provided. Leave as null if you do not wish to use IAM role with Service Accounts."
  type = map(object({
    resources = list(string)
    actions   = list(string)
    effect    = string
  }))
  default = null

  # Example:
  # iam_policy = {
  #   S3Access = {
  #     actions = ["s3:*"]
  #     resources = ["arn:aws:s3:::mybucket"]
  #     effect = "Allow"
  #   },
  #   SecretsManagerAccess = {
  #     actions = ["secretsmanager:GetSecretValue"],
  #     resources = ["arn:aws:secretsmanager:us-east-1:0123456789012:secret:mysecert"]
  #     effect = "Allow"
  #   }
  # }
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE DEPENDENCIES
# Workaround Terraform limitation where there is no module depends_on.
# See https://github.com/hashicorp/terraform/issues/1178 for more details.
# This can be used to make sure the module resources are created after other bootstrapping resources have been created.
# ---------------------------------------------------------------------------------------------------------------------

variable "dependencies" {
  description = "Create a dependency between the resources in this module to the interpolated values in this list (and thus the source resources). In other words, the resources in this module will now depend on the resources backing the values in this list such that those resources need to be created before the resources in this module, and the resources in this module need to be destroyed before the resources in the list."
  type        = list(string)
  default     = []
}
