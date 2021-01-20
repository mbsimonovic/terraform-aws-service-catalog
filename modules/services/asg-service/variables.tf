# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name for the ASG and all other resources created by these templates."
  type        = string
}

variable "ami" {
  description = "The ID of the AMI to run on each instance in the ASG. The AMI needs to have `ec2-baseline` installed, since by default it will run `start_ec2_baseline` on the User Data."
  type        = string
}

variable "instance_type" {
  description = "The type of instance to run in the ASG (e.g. t3.medium)"
  type        = string
}

variable "key_pair_name" {
  description = "The name of a Key Pair that can be used to SSH to the EC2 Instances in the ASG. Set to null if you don't want to enable Key Pair auth."
  type        = string
  default     = null
}

variable "min_size" {
  description = "The minimum number of EC2 Instances to run in this ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances to run in this ASG"
  type        = number
}

variable "desired_capacity" {
  description = "The desired number of EC2 Instances to run in the ASG initially. Note that auto scaling policies may change this value. If you're using auto scaling policies to dynamically resize the cluster, you should actually leave this value as null."
  type        = number
  default     = null
}

variable "min_elb_capacity" {
  description = "Wait for this number of EC2 Instances to show up healthy in the load balancer on creation."
  type        = number
}

variable "listener_ports" {
  description = "The ports the ALB listens on for requests"
  type        = list(number)
  default     = []
}

variable "server_ports" {
  description = "The ports the EC2 instances listen on for requests. A Target Group will be created for each port and any rules specified in var.forward_rules will forward traffic to these Target Groups."
  type        = any
  default     = {}

  # Each entry in the map supports the following attributes:
  #
  # REQUIRED:
  # - server_port        [number]      : The port of the endpoint to be checked (e.g. 80).
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - tags              [map(string)] : A map of tags to apply to the metric alarm. The key is the tag name
  #                                   and the value is the tag value.
  #
  # - protocol                           [string] : The protocol to use for health checks. See:
  #                                                 https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group#protocol
  # - health_check_path                  [string] : The path that the health check should use for requests (e.g. /health or /status).
  #
  # - r53_health_check_path              [string] : The path that you want Amazon Route 53 to request when
  #                                                performing health checks (e.g. /status). Defaults to "/".
  # - r53_health_check_type              [string] : The protocol to use when performing health checks. Valid
  #                                               values are HTTP, HTTPS, HTTP_STR_MATCH, HTTPS_STR_MATCH,
  #                                               TCP, CALCULATED and CLOUDWATCH_METRIC. Defaults to HTTP.
  # - r53_health_check_failure_threshold [number] : The number of consecutive health checks that must pass
  #                                               or fail for the health check to declare your site up or
  #                                               down. Defaults to 2.
  # - r53_health_check_request_interval  [number] : The number of seconds between health checks. Defaults to 30.
  #
  # - enable_lb_health_check [bool]   : Set to false if you want to disable Target Group health's check.
  #                                   Defaults to true.
  # - lb_healthy_threshold   [number] : The number of consecutive health checks *successes* required before
  #                                    considering an unhealthy target healthy. Defaults to 3.
  # - lb_unhealthy_threshold [number] : The number of consecutive health check *failures* required before
  #                                    considering the target unhealthy. Defaults to 3.
  # - lb_request_interval    [number] : The approximate amount of time, in seconds, between health checks
  #                                   of an individual target. Defaults to 30.
  # - lb_timeout             [number] : The amount of time, in seconds, during which no response means a
  #                                   failed health check. Defaults to 10.

  # Example:
  #
  # server_ports = {
  #   "default-http" = {
  #     server_port            = "8080"
  #     protocol               = "HTTP"
  #     health_check_path      = "/health"
  #     r53_health_check_path  = "/health"
  #     enable_lb_health_check = false
  #   }
  # }
}

variable "ami_filters" {
  description = "Properties on the AMI that can be used to lookup a prebuilt AMI for use with the Bastion Host. You can build the AMI using the Packer template bastion-host.json. Only used if var.ami is null. One of var.ami or var.ami_filters is required. Set to null if passing the ami ID directly."
  type = object({
    # List of owners to limit the search. Set to null if you do not wish to limit the search by AMI owners.
    owners = list(string)

    # Name/Value pairs to filter the AMI off of. There are several valid keys, for a full reference, check out the
    # documentation for describe-images in the AWS CLI reference
    # (https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-images.html).
    filters = list(object({
      name   = string
      values = list(string)
    }))
  })
}

variable "forward_listener_rules" {
  description = "Listener rules for a forward action that distributes requests among one or more target groups. By default, sends traffic to the target groups created for the ports in var.server_ports. See comments below for information about the parameters."
  type        = any
  default     = {}

  # Each entry in the map supports the following attributes:
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - priority          [number]                    : A value between 1 and 50000. Leaving it unset will automatically set
  #                                                  the rule with the next available priority after currently existing highest
  #                                                   rule. This value must be unique for each listener.
  # - listener_arns     [list(string)]              : A list of listener ARNs to override `var.listener_arns`
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

variable "redirect_listener_rules" {
  description = "Listener rules for a redirect action. See comments below for information about the parameters."
  type        = map(any)
  default     = {}

  # Each entry in the map supports the following attributes:
  #
  # OPTIONAL (defaults to value of corresponding module input):
  # - priority       [number]: A value between 1 and 50000. Leaving it unset will automatically set the rule with the next
  #                         available priority after currently existing highest rule. This value must be unique for each
  #                         listener.
  # - listener_arns [list(string)]: A list of listener ARNs to override `var.listener_arns`
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

variable "fixed_response_listener_rules" {
  description = "Listener rules for a fixed-response action. See comments below for information about the parameters."
  type        = map(any)
  default     = {}

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
  # - listener_arns [list(string)]: A list of listener ARNs to override `var.listener_arns`
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

variable "listener_arns" {
  description = "A map of all the listeners on the load balancer. The keys should be the port numbers and the values should be the ARN of the listener for that port."
  type        = map(string)
  default     = {}
}

variable "default_forward_target_group_arns" {
  description = "The ARN of the Target Group to which to route traffic."
  type        = list(any)
  default     = []

  # Each entry in the map supports the following attributes:
  # REQUIRED:
  # - arn    [string]: The ARN of the target group.
  # OPTIONAL:
  # - weight [number]: The weight. The range is 0 to 999. Only applies if len(target_group_arns) > 1.
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the Auto Scaling Group"
  type        = string
}

variable "subnet_ids" {
  description = "The list of IDs of the subnets in which to deploy ASG. The list must only contain subnets in var.vpc_id."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "create_route53_entry" {
  description = "Set to true to create a DNS A record in Route 53 for this service."
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for the Auto Scaling Group. Optional if create_route53_entry = false."
  type        = string
  default     = null
}

variable "original_lb_dns_name" {
  description = "The DNS name that was assigned by AWS to the load balancer upon creation"
  type        = string
  default     = null
}

variable "lb_hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for the Auto Scaling Group. Optional if create_route53_entry = false."
  type        = string
  default     = null
}

variable "domain_name" {
  description = "The domain name to register in var.hosted_zone_id (e.g. foo.example.com). Only used if var.create_route53_entry is true."
  type        = string
  default     = null
}

variable "termination_policies" {
  description = "A list of policies to decide how the instances in the auto scale group should be terminated. The allowed values are OldestInstance, NewestInstance, OldestLaunchConfiguration, ClosestToNextInstanceHour, Default."
  type        = list(string)
  default     = []
}

variable "load_balancers" {
  description = "A list of Elastic Load Balancer (ELB) names to associate with this ASG. If you're using the Application Load Balancer (ALB), see var.target_group_arns."
  type        = list(string)
  default     = []
}

variable "allow_inbound_from_security_group_ids" {
  description = "The security group IDs from which to allow access to the ports in var.server_ports"
  default     = []
  type        = list(string)
}

variable "allow_inbound_from_cidr_blocks" {
  description = "The CIDR blocks from which to allow access to the ports in var.server_ports"
  default     = []
  type        = list(string)
}

variable "allow_ssh_security_group_ids" {
  description = "The security group IDs from which to allow SSH access"
  default     = []
  type        = list(string)
}

variable "allow_ssh_from_cidr_blocks" {
  description = "The CIDR blocks from which to allow SSH access"
  default     = []
  type        = list(string)
}

variable "ssh_port" {
  description = "The port at which SSH will be allowed from var.allow_ssh_from_cidr_blocks and var.allow_ssh_security_group_ids"
  default     = 22
  type        = string
}


variable "use_elb_health_checks" {
  description = "Whether or not ELB or ALB health checks should be enabled. If set to true, the load_balancers or target_groups_arns variable should be set depending on the load balancer type you are using. Useful for testing connectivity before health check endpoints are available."
  type        = bool
  default     = true
}

variable "health_check_grace_period" {
  description = "Time, in seconds, after an EC2 Instance comes into service before checking health."
  type        = number
  default     = 300
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration that Terraform should wait for the EC2 Instances to be healthy before timing out."
  type        = string
  default     = "10m"
}

variable "enabled_metrics" {
  description = "A list of metrics the ASG should enable for monitoring all instances in a group. The allowed values are GroupMinSize, GroupMaxSize, GroupDesiredCapacity, GroupInServiceInstances, GroupPendingInstances, GroupStandbyInstances, GroupTerminatingInstances, GroupTotalInstances."
  type        = list(string)
  default     = []

  # Example:
  # enabled_metrics = [
  #    "GroupDesiredCapacity",
  #    "GroupInServiceInstances",
  #    "GroupMaxSize",
  #    "GroupMinSize",
  #    "GroupPendingInstances",
  #    "GroupStandbyInstances",
  #    "GroupTerminatingInstances",
  #    "GroupTotalInstances"
  #  ]
}

variable "tag_asg_id_key" {
  description = "The key for the tag that will be used to associate a unique identifier with this ASG. This identifier will persist between redeploys of the ASG, even though the underlying ASG is being deleted and replaced with a different one."
  type        = string
  default     = "AsgId"
}

variable "custom_tags" {
  description = "A list of custom tags to apply to the EC2 Instances in this ASG. Each item in this list should be a map with the parameters key, value, and propagate_at_launch."
  type = list(object({
    key                 = string
    value               = string
    propagate_at_launch = bool
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     key = "foo"
  #     value = "bar"
  #     propagate_at_launch = true
  #   },
  #   {
  #     key = "baz"
  #     value = "blah"
  #     propagate_at_launch = true
  #   }
  # ]
}

variable "enable_route53_health_check" {
  description = "If set to true, use Route 53 to perform health checks on var.domain_name."
  type        = bool
  default     = false
}

variable "enable_cloudwatch_metrics" {
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your Auto Scaling Group"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns_us_east_1" {
  description = "A list of SNS topic ARNs to notify when the health check changes to ALARM, OK, or INSUFFICIENT_DATA state. Note: these SNS topics MUST be in us-east-1! This is because Route 53 only sends CloudWatch metrics to us-east-1, so we must create the alarm in that region, and therefore, can only notify SNS topics in that region."
  type        = list(string)
  default     = []
}

variable "enable_cloudwatch_log_aggregation" {
  description = "Set to true to add AIM permissions to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
  type        = bool
  default     = true
}

variable "alarms_sns_topic_arn" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications. Also used for the alarms if the Jenkins backup job fails."
  type        = list(string)
  default     = []
}

variable "cloud_init_parts" {
  description = "Cloud init scripts to run on the ASG instances during boot. See the part blocks in https://www.terraform.io/docs/providers/template/d/cloudinit_config.html for syntax"
  type = map(object({
    filename     = string
    content_type = string
    content      = string
  }))
  default = {}
}

variable "enable_fail2ban" {
  description = "Enable fail2ban to block brute force log in attempts. Defaults to true"
  type        = bool
  default     = true
}

variable "enable_ip_lockdown" {
  description = "Enable ip-lockdown to block access to the instance metadata. Defaults to true"
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the instances. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = "ssh-grunt-sudo-users"
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the instances with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = "ssh-grunt-sudo-users"
}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
  default     = ""
}

variable "default_user" {
  description = "The default OS user for the service AMI. For example, for AWS Ubuntu AMIs, the default OS user is 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "metadata_users" {
  description = "List of users on the ASG EC2 instances that should be permitted access to the EC2 metadata."
  type        = list(string)
  default     = []
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
