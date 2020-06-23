# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name used to namespace all resources created by these templates, including the ElastiCache cluster itself (e.g. rediscache). Must be unique in this region. Must be a lowercase string."
  type        = string
}

# For a list of instance types, see https://aws.amazon.com/elasticache/pricing/
# - Note that snapshotting functionality is not compatible with T2 instance types.
# - Note that automatic failover (Multi-AZ) is not supported for T2 and T3 instance node types.
variable "instance_type" {
  description = "The compute and memory capacity of the nodes (e.g. cache.m4.large)."
  type        = string
}

variable "replication_group_size" {
  description = "The total number of nodes in the Redis Replication Group. E.g. 1 represents just the primary node, 2 represents the primary plus a single Read Replica."
  type        = number
}

variable "enable_automatic_failover" {
  description = "Indicates whether Multi-AZ is enabled. When Multi-AZ is enabled, a read-only replica is automatically promoted to a read-write primary cluster if the existing primary cluster fails. If you specify true, you must specify a value greater than 1 for replication_group_size."
  type        = bool
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy RDS."
  type        = string
}

variable "subnet_ids" {
  description = "The list of IDs of the subnets in which to deploy the ElasticCache instances. The list must only contain subnets in var.vpc_id."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

# For a list of versions, see: https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/supported-engine-versions.html
variable "redis_version" {
  description = "Version number of redis to use (e.g. 5.0.6)."
  type        = string
  default     = "5.0.6"
}

variable "port" {
  description = "The port number on which each of the cache nodes will accept connections (e.g. 6379)."
  type        = number
  default     = 6379
}

# We enable at-rest encryption and in-transit encryption by default, however this can have a performance impact
# during operations. You should benchmark your data with and without encryption to determine the performance
# impact for your use cases. For more information, see: https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/at-rest-encryption.html
variable "enable_at_rest_encryption" {
  description = "Whether to enable encryption at rest."
  type        = bool
  default     = true
}

variable "enable_transit_encryption" {
  description = "Whether to enable encryption in transit."
  type        = bool
  default     = true
}

# By default, run backups from 2-3am EST, which is 6-7am UTC
variable "snapshot_window" {
  description = "The daily time range during which automated backups are created (e.g. 04:00-09:00). Time zone is UTC. Performance may be degraded while a backup runs. Set to empty string to disable snapshots."
  type        = string
  default     = "06:00-07:00"
}

variable "snapshot_retention_limit" {
  description = "The number of days for which ElastiCache will retain automatic cache cluster snapshots before deleting them. Set to 0 to disable snapshots."
  type        = number
  default     = 7
}

# By default, do maintenance from 3-4am EST on Saturday, which is 7-8am UTC.
variable "maintenance_window" {
  description = "Specifies the weekly time range for when maintenance on the cache cluster is performed (e.g. sun:05:00-sun:09:00). The format is ddd:hh24:mi-ddd:hh24:mi (24H Clock UTC). The minimum maintenance window is a 60 minute period."
  type        = string
  default     = "sat:07:00-sat:08:00"
}

variable "apply_immediately" {
  description = "Specifies whether any modifications are applied immediately, or during the next maintenance window."
  type        = bool
  default     = false
}

variable "cluster_mode" {
  description = "Specifies the number of shards and replicas per shard in the cluster. The list should contain a single map with keys 'num_node_groups' and 'replicas_per_node_group' set to desired integer values."
  type = list(object({
    num_node_groups         = number
    replicas_per_node_group = number
  }))
  default = []
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

variable "enable_cloudwatch_metrics" {
  description = "When true, enable CloudWatch metrics for the manual snapshots created for the purpose of sharing with another account."
  type        = bool
  default     = true
}

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
  description = "The ARN of the SNS Topic to which notifications will be sent when a Replication Group event happens, such as an automatic failover (e.g. arn:aws:sns:*:123456789012:my_sns_topic). An empty string is a valid value if you do not wish to receive notifications via SNS."
  type        = string
  default     = ""
}
