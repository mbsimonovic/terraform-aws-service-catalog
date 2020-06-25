# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name used to namespace all resources created by these templates, including the ElastiCache cluster itself. Must be unique in this region. Must be a lowercase string."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy RDS."
  type        = string
}

variable "subnet_ids" {
  description = "The list of IDs of the subnets in which to deploy the ElasticCache instances. The list must only contain subnets in var.vpc_id."
  type        = list(string)
}

# For a list of instance types, see https://aws.amazon.com/elasticache/pricing/
# - Note that snapshotting functionality is not compatible with T2 instance types.
# - Note that automatic failover (Multi-AZ) is not supported for T2 and T3 instance node types.
variable "instance_type" {
  description = "The compute and memory capacity of the nodes (e.g. cache.m4.large)."
  type        = string
}

variable "num_cache_nodes" {
  description = "The initial number of cache nodes that the cache cluster will have. Must be between 1 and 20."
  type        = number
}

variable "az_mode" {
  description = "Specifies whether the nodes in this Memcached node group are created in a single Availability Zone or created across multiple Availability Zones in the cluster's region. Valid values for this parameter are single-az or cross-az. If you want to choose cross-az, num_cache_nodes must be greater than 1."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

# For a list of versions, see: https://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/SelectEngine.html
variable "memcached_version" {
  description = "Version number of memcached to use (e.g. 1.5.16)."
  type        = string
  default     = "1.5.16"
}

variable "port" {
  description = "The port number on which each of the cache nodes will accept connections (e.g. 11211)."
  type        = number
  default     = 11211
}

# By default, do maintenance from 3-4am EST on Saturday, which is 7-8am UTC.
variable "maintenance_window" {
  description = "Specifies the weekly time range for when maintenance on the cache cluster is performed (e.g. sun:05:00-sun:09:00). The format is ddd:hh24:mi-ddd:hh24:mi (24H Clock UTC). The minimum maintenance window is a 60 minute period."
  type        = string
  default     = "sat:07:00-sat:08:00"
}

variable "apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately, or during the next maintenance window."
  type        = bool
  default     = false
}

variable "allow_connections_from_cidr_blocks" {
  description = "The list of network CIDR blocks to allow network access to ElastiCache from. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the ElastiCache instances to be reachable."
  type        = list(string)
  default     = []
}

variable "allow_connections_from_security_groups" {
  description = "The list of IDs or Security Groups to allow network access to ElastiCache from. All security groups must either be in the VPC specified by var.vpc_id, or a peered VPC with the VPC specified by var.vpc_id. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the ElastiCache instances to be reachable."
  type        = list(string)
  default     = []
}

# Monitoring settings

variable "enable_cloudwatch_alarms" {
  description = "Set to true to enable several basic CloudWatch alarms around CPU usage, memory usage, and disk space usage. If set to true, make sure to specify SNS topics to send notifications to using var.alarms_sns_topic_arn."
  type        = bool
  default     = true
}

variable "alarms_sns_topic_arns" {
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications."
  type        = list(string)
  default     = []
}

variable "sns_topic_for_notifications" {
  description = "The ARN of the SNS Topic to which notifications will be sent when the ElastiCache alarms change to ALARM, OK, or INSUFFICIENT_DATA state (e.g. arn:aws:sns:*:123456789012:my_sns_topic). An empty string is a valid value if you do not wish to receive notifications via SNS."
  type        = string
  default     = ""
}
