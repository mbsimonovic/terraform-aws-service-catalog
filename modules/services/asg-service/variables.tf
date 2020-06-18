# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name for the ASG and all other resources created by these templates."
  type        = string
}

variable "ami" {
  description = "The ID of the AMI to run on each EC2 Instance in the ASG."
  type        = string
}

variable "init_script_path" {
  description = "The path to an initialization script to execute in User Data while each Instance is booting. This should be a script that's built into var.ami and used to start your service. Terraform will pass several variables to this script, including AWS region, VPC name, and ASG name."
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

variable "server_port" {
  description = "The port the EC2 instances listen on for HTTP requests"
  type        = number
}

variable "alb_listener_rule_configs" {
  description = "A list of all ALB Listener Rules that should be attached to an existing ALB Listener. These rules configure the ALB to send requests that come in on certain ports and paths to this service. Each item in the list should be a map with the keys port (the port to match), path (the path to match), and priority (earlier priorities are matched first)."
  type = list(object({
    port     = number
    path     = string
    priority = number
  }))

  # Example:
  # default = [
  #   {
  #     port     = 80
  #     path     = "/foo/*"
  #     priority = 100
  #   },
  #   {
  #     port     = 443
  #     path     = "/foo/*"
  #     priority = 100
  #   }
  # ]
}

variable "min_elb_capacity" {
  description = "Wait for this number of EC2 Instances to show up healthy in the load balancer on creation."
  type        = number
}

variable "alb_listener_arn" {
  description = "The ARN of the ALB listener."
  type        = string
}

variable "health_check_path" {
  description = "The path, without any leading slash, that can be used as a health check (e.g. healthcheck). Should return a 200 OK when the service is up and running."
  type        = string
}

variable "health_check_protocol" {
  description = "The protocol to use for health checks. Should be one of HTTP, HTTPS."
  type        = string
}

variable "vpn_security_group_ids" {
  type = list(string)
}

variable "user_data" {
  type    = string
  default = null
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the Auto Scaling Group"
  type        = string
}

variable "subnet_ids" {
  description = "The list of IDs of the subnets in which to deploy ASG. The list must only contain subnets in var.vpc_id."
  type        = list(string)
}

variable "alb_security_groups" {
  type = list(string)
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

variable "original_alb_dns_name" {
  type    = string
  default = null
}

variable "alb_hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for the Auto Scaling Group. Optional if create_route53_entry = false."
  type        = string
  default     = null
}

variable "domain_name" {
  description = "The domain name to register in var.hosted_zone_id (e.g. foo.example.com). Only used if var.create_route53_entry is true."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
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

variable "availability_zones" {
  description = "A list of availability zones the ASG should use. The subnets in var.vpc_subnet_ids must reside in these Availability Zones."
  type        = list(string)
  default     = []
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
  description = "Set to true to add IAM permissions to send custom metrics to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts to get memory and disk metrics in CloudWatch for your Auto Scaling Group"
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
  description = "Set to true to add AIM permissions to send logs to CloudWatch. This is useful in combination with https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts to do log aggregation in CloudWatch."
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

variable "enable_ssh_grunt" {
  description = "Set to true to add IAM permissions for ssh-grunt (https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt), which will allow you to manage SSH access via IAM groups."
  type        = bool
  default     = true
}

variable "ssh_grunt_iam_group" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the instances. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "ssh_grunt_iam_group_sudo" {
  description = "If you are using ssh-grunt, this is the name of the IAM group from which users will be allowed to SSH to the instances with sudo permissions. To omit this variable, set it to an empty string (do NOT use null, or Terraform will complain)."
  type        = string
  default     = ""
}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
  default     = ""
}

variable "default_user" {
  description = "The default OS user for the Jenkins AMI. For AWS Ubuntu AMIs, which is what the Packer template in jenkins-ubunutu.json uses, the default OS user is 'ubuntu'."
  type        = string
  default     = "ubuntu"
}

variable "owner" { // TODO better name??
  type        = string
  default     = "ec2-user"
}

