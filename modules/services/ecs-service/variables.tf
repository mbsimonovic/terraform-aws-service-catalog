# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables must be passed in by the calling Terraform code.
# ---------------------------------------------------------------------------------------------------------------------

variable "service_name" {
  description = "The name of the ECS service (e.g. my-service-stage)"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "The ARN of the cluster to which the ecs service should be deployed."
  type        = string
}

variable "ecs_cluster_name" {
  description = "The name of the ecs cluster to deploy the ecs service onto."
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

variable "capacity_provider_strategy" {
  description = "The capacity provider strategy to use for the service. Note that the capacity providers have to be present on the ECS cluster before deploying the ECS service. When provided, var.launch_type is ignored."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
  default = []

  # Example:
  # capacity_provider_strategy = [
  #    {
  #      capacity_provider = "FARGATE"
  #      weight            = 1
  #      base              = 2
  #    },
  #    {
  #      capacity_provider = "FARGATE_SPOT"
  #      weight            = 2
  #      base              = null
  #    },
  # ]
}

variable "launch_type" {
  description = "The launch type of the ECS service. Must be one of EC2 or FARGATE. When using FARGATE, you must set the network mode to awsvpc and configure it. When using EC2, you can configure the placement strategy using the variables var.placement_strategy_type, var.placement_strategy_field, var.placement_constraint_type, var.placement_constraint_expression. This variable is ignored if var.capacity_provider_strategy is provided."
  type        = string
  default     = "EC2"
}

variable "network_mode" {
  description = "The Docker networking mode to use for the containers in the task. The valid values are none, bridge, awsvpc, and host. If the network_mode is set to awsvpc, you must configure var.network_configuration."
  type        = string
  default     = "bridge"
}

variable "network_configuration" {
  description = "The configuration to use when setting up the VPC network mode. Required and only used if network_mode is awsvpc."
  type = object({
    subnets          = list(string)
    security_groups  = list(string)
    assign_public_ip = bool
  })
  default = null
}

variable "task_cpu" {
  description = "The CPU units for the instances that Fargate will spin up. Options here: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size. Required when using FARGATE launch type."
  type        = number
  default     = null
}

variable "task_memory" {
  description = "The memory units for the instances that Fargate will spin up. Options here: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html#fargate-tasks-size. Required when using FARGATE launch type."
  type        = number
  default     = null
}

variable "placement_strategy_type" {
  description = "The strategy to use when placing ECS tasks on EC2 instances. Can be binpack (default), random, or spread."
  type        = string
  default     = "binpack"
}

variable "placement_strategy_field" {
  description = "The field to apply the placement strategy against. For the spread placement strategy, valid values are instanceId (or host, which has the same effect), or any platform or custom attribute that is applied to a container instance, such as attribute:ecs.availability-zone. For the binpack placement strategy, valid values are cpu and memory. For the random placement strategy, this field is not used."
  type        = string
  default     = "cpu"
}

variable "placement_constraint_type" {
  description = "The type of constraint to apply for container instance placement. The only valid values at this time are memberOf and distinctInstance."
  type        = string
  default     = "memberOf"
}

variable "placement_constraint_expression" {
  description = "Cluster Query Language expression to apply to the constraint for matching. Does not need to be specified for the distinctInstance constraint type."
  type        = string
  default     = "attribute:ecs.ami-id != 'ami-fake'"
}

variable "secrets_manager_arns" {
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

variable "service_tags" {
  description = "A map of tags to apply to the ECS service. Each item in this list should be a map with the parameters key and value."
  type        = map(string)
  default     = {}
  # Example:
  #   {
  #     key1 = "value1"
  #     key2 = "value2"
  #   }
}

variable "task_definition_tags" {
  description = "A map of tags to apply to the task definition. Each item in this list should be a map with the parameters key and value."
  type        = map(string)
  default     = {}
  # Example:
  #   {
  #     key1 = "value1"
  #     key2 = "value2"
  #   }
}

variable "propagate_tags" {
  description = "Whether tags should be propogated to the tasks from the service or from the task definition. Valid values are SERVICE and TASK_DEFINITION. Defaults to SERVICE. If set to null, no tags are created for tasks."
  type        = string
  default     = "SERVICE"
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

variable "ecs_node_port_mappings" {
  description = "A map of ports to be opened via security groups applied to the EC2 instances that back the ECS cluster, when not using fargate. The key should be the container port and the value should be what host port to map it to."
  type        = map(number)
  default     = {}
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
  description = "The ID of the VPC in which to create the target group. Only used if var.elb_target_groups is set."
  type        = string
  default     = null
}

variable "elb_target_group_deregistration_delay" {
  description = "The amount of time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds. Only used if var.elb_target_groups is set."
  type        = number
  default     = 300
}

variable "elb_slow_start" {
  description = "The amount time for targets to warm up before the load balancer sends them a full share of requests. The range is 30-900 seconds or 0 to disable. The default value is 0 seconds. Only used if var.elb_target_groups is set."
  type        = number
  default     = 0
}

variable "use_alb_sticky_sessions" {
  description = "If true, the ALB will use use Sticky Sessions as described at https://goo.gl/VLcNbk. Only used if var.elb_target_groups is set. Note that this can only be true when associating with an ALB. This cannot be used with CLBs or NLBs."
  type        = bool
  default     = false
}

variable "alb_sticky_session_type" {
  description = "The type of Sticky Sessions to use. See https://goo.gl/MNwqNu for possible values. Only used if var.elb_target_groups is set."
  type        = string
  default     = "lb_cookie"
}

variable "alb_sticky_session_cookie_duration" {
  description = "The time period, in seconds, during which requests from a client should be routed to the same Target. After this time period expires, the load balancer-generated cookie is considered stale. The acceptable range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds). Only used if var.elb_target_groups is set."
  type        = number
  default     = 86400
}

### LB Health Check configurations

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2,147,483,647. Only valid for services configured to use load balancers."
  type        = number
  default     = 0
}

variable "health_check_enabled" {
  description = "If true, enable health checks on the target group. Only applies to ELBv2. For CLBs, health checks are not configurable."
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "The approximate amount of time, in seconds, between health checks of an individual Target. Minimum value 5 seconds, Maximum value 300 seconds."
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "The ping path that is the destination on the Targets for health checks. Required when using ALBs."
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "The port the ELB uses when performing health checks on Targets. The default is to use the port on which each target receives traffic from the load balancer, indicated by the value 'traffic-port'."
  type        = string
  default     = "traffic-port"
}

variable "health_check_timeout" {
  description = "The amount of time, in seconds, during which no response from a Target means a failed health check. The acceptable range is 2 to 60 seconds."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "The number of consecutive successful health checks required before considering an unhealthy Target healthy. The acceptable range is 2 to 10."
  type        = number
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  description = "The number of consecutive failed health checks required before considering a target unhealthy. The acceptable range is 2 to 10. For NLBs, this value must be the same as the health_check_healthy_threshold."
  type        = number
  default     = 2
}

variable "health_check_matcher" {
  description = "The HTTP codes to use when checking for a successful response from a Target. You can specify multiple values (e.g. '200,202') or a range of values (e.g. '200-299'). Required when using ALBs."
  type        = string
  default     = "200"
}

variable "default_listener_arns" {
  description = "A map of all the listeners on the load balancer. The keys should be the port numbers and the values should be the ARN of the listener for that port."
  type        = map(string)
}

variable "default_listener_ports" {
  description = "The default port numbers on the load balancer to attach listener rules to. You can override this default on a rule-by-rule basis by setting the listener_ports parameter in each rule. The port numbers specified in this variable and the listener_ports parameter must exist in var.listener_arns."
  type        = list(string)
}

variable "forward_rules" {
  type    = any
  default = {}

  # Each entry in the map supports the following attributes:
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - priority          [number]                    : A value between 1 and 50000. Leaving it unset will automatically set
  #                                                  the rule with the next available priority after currently existing highest
  #                                                   rule. This value must be unique for each listener.
  # - listener_arns     [list(string)]              : A list of listener ARNs to override `var.default_listener_arns`
  # - stickiness        [map(object[Stickiness])]   : Target group stickiness for the rule. Only applies if more than one
  #                                                  target_group_arn is defined.

  # Wildcard characters:
  # * - matches 0 or more characters
  # ? - matches exactly 1 character
  # To search for a literal '*' or '?' character in a query string, escape the character with a backslash (\).

  # Conditions (need to specify at least one):
  # - path_patterns        [list(string)]     : A list of paths to match (note that "/foo" is different than "/foo/").
  #                                            Comparison is case sensitive. Wildcard characters supported: * and ?.
  #                                            It is compared to the path of the URL, not it's query string. To compare
  #                                            against query string, use the `query_strings` condition.
  # - host_headers         [list(string)]     : A list of host header patterns to match. Comparison is case insensitive.
  #                                            Wildcard characters supported: * and ?.
  # - source_ips           [list(string)]     : A list of IP CIDR notations to match. You can use both IPv4 and IPv6
  #                                            addresses. Wildcards are not supported. Condition is not satisfied by the
  #                                            addresses in the `X-Forwarded-For` header, use `http_headers` condition instead.
  # - query_strings        [list(map(string))]: Query string pairs or values to match. Comparison is case insensitive.
  #                                            Wildcard characters supported: * and ?. Only one pair needs to match for
  #                                            the condition to be satisfied.
  # - http_request_methods [list(string)]     : A list of HTTP request methods or verbs to match. Only allowed characters are
  #                                            A-Z, hyphen (-) and underscore (_). Comparison is case sensitive. Wildcards
  #                                            are not supported. AWS recommends that GET and HEAD requests are routed in the
  #                                            same way because the response to a HEAD request may be cached.

  # Example:
  #  {
  #    "foo" = {
  #      priority = 120
  #
  #      host_headers         = ["www.foo.com", "*.foo.com"]
  #      path_patterns        = ["/foo/*"]
  #      source_ips           = ["127.0.0.1/32"]
  #      http_request_methods = ["GET"]
  #      query_strings = [
  #        {
  #           key   = "foo"  # Key is optional, this can be ommited.
  #          value = "bar"
  #        }, {
  #          value = "hello"
  #        }
  #     ]
  #   }
  # }
}

variable "redirect_rules" {
  type    = map(any)
  default = {}

  # Each entry in the map supports the following attributes:
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - priority       [number]: A value between 1 and 50000. Leaving it unset will automatically set the rule with the next
  #                         available priority after currently existing highest rule. This value must be unique for each
  #                         listener.
  # - listener_arns [list(string)]: A list of listener ARNs to override `var.default_listener_arns`
  # - status_code   [string]: The HTTP redirect code. The redirect is either permanent `HTTP_301` or temporary `HTTP_302`.
  #
  # The URI consists of the following components: `protocol://hostname:port/path?query`. You must modify at least one of
  # the following components to avoid a redirect loop: protocol, hostname, port, or path. Any components that you do not
  # modify retain their original values.
  # - host        [string]: The hostname. The hostname can contain #{host}.
  # - path        [string]: The absolute path, starting with the leading "/". The path can contain `host`, `path`, and `port`.
  # - port        [string]: The port. Specify a value from 1 to 65525.
  # - protocol    [string]: The protocol. Valid values are `HTTP` and `HTTPS`. You cannot redirect HTTPS to HTTP.
  # - query       [string]: The query params. Do not include the leading "?".
  #
  # Wildcard characters:
  # * - matches 0 or more characters
  # ? - matches exactly 1 character
  # To search for a literal '*' or '?' character in a query string, escape the character with a backslash (\).
  #
  # Conditions (need to specify at least one):
  # - path_patterns        [list(string)]     : A list of paths to match (note that "/foo" is different than "/foo/").
  #                                            Comparison is case sensitive. Wildcard characters supported: * and ?.
  #                                            It is compared to the path of the URL, not it's query string. To compare
  #                                            against query string, use the `query_strings` condition.
  # - host_headers         [list(string)]     : A list of host header patterns to match. Comparison is case insensitive.
  #                                            Wildcard characters supported: * and ?.
  # - source_ips           [list(string)]     : A list of IP CIDR notations to match. You can use both IPv4 and IPv6
  #                                            addresses. Wildcards are not supported. Condition is not satisfied by the
  #                                            addresses in the `X-Forwarded-For` header, use `http_headers` condition instead.
  # - query_strings        [list(map(string))]: Query string pairs or values to match. Comparison is case insensitive.
  #                                            Wildcard characters supported: * and ?. Only one pair needs to match for
  #                                            the condition to be satisfied.
  # - http_request_methods [list(string)]     : A list of HTTP request methods or verbs to match. Only allowed characters are
  #                                            A-Z, hyphen (-) and underscore (_). Comparison is case sensitive. Wildcards
  #                                            are not supported. AWS recommends that GET and HEAD requests are routed in the
  #                                            same way because the response to a HEAD request may be cached.

  # Example:
  #  {
  #    "old-website" = {
  #      priority = 120
  #      port     = 443
  #      protocol = "HTTPS"
  #
  #      status_code = "HTTP_301"
  #      host  = "gruntwork.in"
  #      path  = "/signup"
  #      query = "foo"
  #
  #    Conditions:
  #      host_headers         = ["foo.com", "www.foo.com"]
  #      path_patterns        = ["/health"]
  #      source_ips           = ["127.0.0.1"]
  #      http_request_methods = ["GET"]
  #      query_strings = [
  #        {
  #          key   = "foo"  # Key is optional, this can be ommited.
  #          value = "bar"
  #        }, {
  #          value = "hello"
  #        }
  #      ]
  #    }
  #  }
}

variable "fixed_response_rules" {
  type    = map(any)
  default = {}

  # Each entry in the map supports the following attributes:
  #
  # REQUIRED
  # - content_type [string]: The content type. Valid values are `text/plain`, `text/css`, `text/html`, `application/javascript`
  #                          and `application/json`.
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - priority      [number]       : A value between 1 and 50000. Leaving it unset will automatically set the rule with the next
  #                                 available priority after currently existing highest rule. This value must be unique for each
  #                                 listener.
  # - listener_arns [list(string)]: A list of listener ARNs to override `var.default_listener_arns`
  # - message_body  [string]      : The message body.
  # - status_code   [string]      : The HTTP response code. Valid values are `2XX`, `4XX`, or `5XX`.
  #
  # Wildcard characters:
  # * - matches 0 or more characters
  # ? - matches exactly 1 character
  # To search for a literal '*' or '?' character in a query string, escape the character with a backslash (\).
  #
  # Conditions (need to specify at least one):
  # - path_patterns        [list(string)]     : A list of paths to match (note that "/foo" is different than "/foo/").
  #                                            Comparison is case sensitive. Wildcard characters supported: * and ?.
  #                                            It is compared to the path of the URL, not it's query string. To compare
  #                                            against query string, use the `query_strings` condition.
  # - host_headers         [list(string)]     : A list of host header patterns to match. Comparison is case insensitive.
  #                                            Wildcard characters supported: * and ?.
  # - source_ips           [list(string)]     : A list of IP CIDR notations to match. You can use both IPv4 and IPv6
  #                                            addresses. Wildcards are not supported. Condition is not satisfied by the
  #                                            addresses in the `X-Forwarded-For` header, use `http_headers` condition instead.
  # - query_strings        [list(map(string))]: Query string pairs or values to match. Comparison is case insensitive.
  #                                            Wildcard characters supported: * and ?. Only one pair needs to match for
  #                                            the condition to be satisfied.
  # - http_request_methods [list(string)]     : A list of HTTP request methods or verbs to match. Only allowed characters are
  #                                            A-Z, hyphen (-) and underscore (_). Comparison is case sensitive. Wildcards
  #                                            are not supported. AWS recommends that GET and HEAD requests are routed in the
  #                                            same way because the response to a HEAD request may be cached.

  # Example:
  #  {
  #    "health-path" = {
  #      priority     = 130
  #
  #      content_type = "text/plain"
  #      message_body = "HEALTHY"
  #      status_code  = "200"
  #
  #    Conditions:
  #    You need to provide *at least ONE* per set of rules. It should contain one of the following:
  #      host_headers         = ["foo.com", "www.foo.com"]
  #      path_patterns        = ["/health"]
  #      source_ips           = ["127.0.0.1"]
  #      http_request_methods = ["GET"]
  #      query_strings = [
  #        {
  #          key   = "foo"  # Key is optional, this can be ommited.
  #          value = "bar"
  #        }, {
  #          value = "hello"
  #        }
  #      ]
  #    }
  #  }
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

variable "iam_policy" {
  description = "An object defining the policy to attach to the ECS task. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement."
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

variable "secrets_access" {
  description = "A list of ARNs of Secrets Manager secrets that the task should have permissions to read. The IAM role for the task will be granted `secretsmanager:GetSecretValue` for each secret in the list. The ARN can be either the complete ARN, including the randomly generated suffix, or the ARN without the suffix. If the latter, the module will look up the full ARN automatically. This is helpful in cases where you don't yet know the randomly generated suffix because the rest of the ARN is a predictable value."
  type        = list(string)
  default     = []
  # Example:
  # secrets_access = [
  #   "arn:aws:secretsmanager:us-east-1:123456789012:secret:example",
  #    "arn:aws:secretsmanager:us-east-1:123456789012:secret:example-123456",
  #  ]
}

variable "custom_iam_policy_prefix" {
  description = "Prefix for name of the custom IAM policies created by this module (those resulting from var.iam_policy and var.secrets_access). If omitted, defaults to var.service_name."
  type        = string
  default     = null
}

variable "custom_iam_role_name_prefix" {
  description = "Prefix for name of the IAM role used by the ECS task."
  type        = string
  default     = null
}

variable "custom_task_execution_iam_role_name_prefix" {
  description = "Prefix for name of task execution IAM role and policy that grants access to CloudWatch and ECR."
  type        = string
  default     = null
}

variable "custom_ecs_service_role_name" {
  description = "The name to use for the ECS Service IAM role, which is used to grant permissions to the ECS service to register the task IPs to ELBs."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# VOLUMES
# ---------------------------------------------------------------------------------------------------------------------

variable "volumes" {
  description = "(Optional) A map of volume blocks that containers in your task may use. The key should be the name of the volume and the value should be a map compatible with https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#volume-block-arguments, but not including the name parameter."
  # Ideally, this would be a map of (string, object), but object does not support optional properties, whereas the
  # volume definition supports a number of optional properties. We can't use a map(any) either, as that would require
  # the values to all have the same type, and due to optional parameters, that wouldn't work either. So, we have to
  # lamely fall back to any.
  type    = any
  default = {}

  # Example:
  # volumes = {
  #   datadog = {
  #     host_path = "/var/run/datadog"
  #   }
  #
  #   logs = {
  #     host_path = "/var/log"
  #     docker_volume_configuration = {
  #       scope         = "shared"
  #       autoprovision = true
  #       driver        = "local"
  #     }
  #   }
  # }
}

variable "efs_volumes" {
  description = "(Optional) A map of EFS volumes that containers in your task may use. Each item in the list should be a map compatible with https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#efs-volume-configuration-arguments."
  type = map(object({
    file_system_id          = string # required
    container_path          = string # required
    root_directory          = string
    transit_encryption      = string
    transit_encryption_port = number
    access_point_id         = string
    iam                     = string
  }))
  default = {}

  # Example:
  # efs_volumes = {
  #   jenkins = {
  #     file_system_id          = "fs-a1bc234d"
  #     container_path          = "/efs"
  #     root_directory          = "/jenkins"
  #     transit_encryption      = "ENABLED"
  #     transit_encryption_port = 2999
  #     access_point_id         = "fsap-123a4b5c5d7891234"
  #     iam                     = "ENABLED"
  #   }
  # }
}


# ---------------------------------------------------------------------------------------------------------------------
# ROUTE 53 RECORD
# ---------------------------------------------------------------------------------------------------------------------

variable "create_route53_entry" {
  description = "Set to true if you want a DNS record automatically created and pointed at the the load balancer for the ECS service"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name to create a route 53 record for. This DNS record will point to the load balancer for the ECS service"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone into which the Route 53 DNS record should be written"
  type        = string
  default     = null
}

variable "enable_route53_health_check" {
  description = "Set this to true to create a route 53 health check and Cloudwatch alarm that will alert if your domain becomes unreachable"
  type        = bool
  default     = false
}

variable "alarm_sns_topic_arns_us_east_1" {
  description = "A list of SNS topic ARNs to notify when the route53 health check changes to ALARM, OK, or INSUFFICIENT_DATA state. Note: these SNS topics MUST be in us-east-1! This is because Route 53 only sends CloudWatch metrics to us-east-1, so we must create the alarm in that region, and therefore, can only notify SNS topics in that region"
  type        = list(string)
  default     = []
}

variable "route53_health_check_path" {
  description = "The path, without any leading slash, that can be used as a health check (e.g. healthcheck) by Route 53. Should return a 200 OK when the service is up and running."
  type        = string
  default     = "/"
}

variable "route53_health_check_protocol" {
  description = "The protocol to use for Route 53 health checks. Should be one of HTTP, HTTPS."
  type        = string
  default     = "HTTP"
}

variable "route53_health_check_port" {
  description = "The port to use for Route 53 health checks. This should be the port for the service that is available at the publicly accessible domain name (var.domain_name)."
  type        = number
  default     = 80
}

variable "original_lb_dns_name" {
  description = "The DNS name that was assigned by AWS to the load balancer upon creation"
  type        = string
  default     = null
}

variable "lb_hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record pointed to the ECS service's load balancer"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY CIRCUIT BREAKER
# ---------------------------------------------------------------------------------------------------------------------

variable "deployment_circuit_breaker_enabled" {
  description = "Set to 'true' to prevent the task from attempting to continuously redeploy after a failed health check."
  type = bool
  default = false
}

variable "deployment_circuit_breaker_rollback" {
  description = "Set to 'true' to also automatically roll back to the last successful deployment. deploy_circuit_breaker_enabled must also be true to enable this behavior."
  type = bool
  default = false
}

# ---------------------------------------------------------------------------------------------------------------------
# PROXY CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "proxy_configuration_container_name" {
  description = "Use the name of the Envoy proxy container from `container_definitions` as the container name."
  type = string
  default = null
}

variable "proxy_configuration_properties" {
  description = "A map of network configuration parameters to provide the Container Network Interface (CNI) plugin."
  type = map(string)
  default = null

  # Example:
  # properties = {
  #   AppPorts         = "8080"
  #   EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
  #   IgnoredUID       = "1337"
  #   ProxyEgressPort  = 15001
  #   ProxyIngressPort = 15000
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
