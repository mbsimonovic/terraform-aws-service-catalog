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

variable "keypair_name" {
  description = "The name of a Key Pair that can be used to SSH to the EC2 Instances in the ASG. Set to null if you don't want to enable Key Pair auth."
  type        = string
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
  description = "The desired number of EC2 Instances to run in the ASG initially. Note that auto scaling policies may change this value."
  type        = number
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

variable "using_end_to_end_encryption" {
  type = bool
}

variable "alb_listener_arn" {

}

//variable "include_elasticsearch_url" {
//  type = bool
//}

variable "iam_users_defined_in_separate_account" {
  type = bool
}

variable "mgmt_vpc_name" {
  type = string
}

//{{- if .IamUsersDefinedInSeparateAccount }}

variable "external_account_ssh_grunt_role_arn" {
  description = "Since our IAM users are defined in a separate AWS account, this variable is used to specify the ARN of an IAM role that allows ssh-grunt to retrieve IAM group and public SSH key info from that account."
  type        = string
  default     = null
}
//{{- end }}

variable "is_internal_alb" {
  description = "If set to true, create only private DNS entries. We should be able to compute this from the ALB automatically, but can't, due to a Terraform limitation (https://goo.gl/gq5Qyk)."
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

variable "hosted_zone_id" {
  description = "The ID of the Route 53 Hosted Zone in which to create a DNS A record for the Auto Scaling Group."
  type        = string
}

variable "original_alb_dns_name" {
  type = string
}

variable "alb_hosted_zone_id" {
  type = string
}

variable "alb_security_groups" {
  type = list(string)
}

//{{- if .IncludeDatabaseUrl }}
//
//variable "db_remote_state_path" {
//  description = "The path to the DB's remote state. This path does not need to include the region or VPC name. Example: data-stores/rds/terraform.tfstate."
//  type        = string
//  default     = "data-stores/rds/terraform.tfstate"
//}
//{{- end }}
//
//{{- if .IncludeRedisUrl }}
//
//variable "redis_remote_state_path" {
//  description = "The path to Redis' remote state. This path does not need to include the region or VPC name. Example: data-stores/redis/terraform.tfstate."
//  type        = string
//  default     = "data-stores/redis/terraform.tfstate"
//}
//{{- end }}
//
//{{- if .IncludeMemcachedUrl }}
//
//variable "memcached_remote_state_path" {
//  description = "The path to Memcached remote state. This path does not need to include the region or VPC name. Example: data-stores/memcached/terraform.tfstate."
//  type        = string
//  default     = "data-stores/memcached/terraform.tfstate"
//}
//{{- end }}
//
//{{- if .IncludeMongoDbUrl }}
//
//variable "mongodb_remote_state_path" {
//  description = "The path to MongoDb remote state. This path does not need to include the region or VPC name. Example: data-stores/mongodb/terraform.tfstate."
//  type        = string
//  default     = "data-stores/mongodb/terraform.tfstate"
//}
//{{- end }}
//
//{{- if .IncludeElasticsearchUrl }}
//
//variable "elasticsearch_remote_state_path" {
//  description = "The path to Elasticsearch remote state. This path does not need to include the region or VPC name. Example: data-stores/elasticsearch/terraform.tfstate."
//  type        = string
//  default     = "data-stores/elasticsearch/terraform.tfstate"
//}
//{{- end }}

variable "create_route53_entry" {
  description = "Set to true to create a DNS A record in Route 53 for this service."
  type        = bool
  default     = false
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

variable "terraform_state_kms_master_key" {
  description = "Path base name of the kms master key to use. This should reflect what you have in your infrastructure-live folder."
  type        = string
  default     = "kms-master-key"
}
