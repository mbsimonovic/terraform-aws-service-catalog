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
  default = null
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

}

variable "iam_users_defined_in_separate_account" {
  type = bool
}

variable "external_account_auto_deploy_iam_role_arns" {
  description = "A list of IAM role ARNs in other AWS accounts that ASG will be able to assume to do automated deployment in those accounts."
//  type        = list(string)
  default     = {ssh_grunt: []}
}

variable "is_internal_alb" {
  description = "If the ALB should only accept traffic from within the VPC, set this to true. If it should accept traffic from the public Internet, set it to false."
  type        = bool
}

variable "health_check_path" {
  description = "The path, without any leading slash, that can be used as a health check (e.g. healthcheck). Should return a 200 OK when the service is up and running."
  type        = string
}

variable "health_check_protocol" {
  description = "The protocol to use for health checks. Should be one of HTTP, HTTPS."
  type        = string
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
  default = []
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

variable "vpn_security_group_ids" {
  type = list(string)
}

variable "user_data" {
  type    = string
  default = null
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the Auto Scaling Group"
  type        = string
}


variable "original_alb_dns_name" {
  type = string
}


variable "alb_security_groups" {
  type = list(string)
}

variable "create_route53_entry" {
  description = "Set to true to create a DNS A record in Route 53 for this service."
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for the Auto Scaling Group. Optional if create_route53_entry = false."
  type        = string
  default = null
}

variable "alb_hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for the Auto Scaling Group. Optional if create_route53_entry = false."
  type = string
  default = null
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
