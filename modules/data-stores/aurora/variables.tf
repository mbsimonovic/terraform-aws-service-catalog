# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module
# ---------------------------------------------------------------------------------------------------------------------

# Cluster configuration

variable "name" {
  description = "The name used to namespace all the Aurora resources created by these templates, including the cluster and cluster instances (e.g. drupaldb). Must be unique in this region. Must be a lowercase string."
  type        = string
}

variable "instance_count" {
  description = "The number of DB instances, including the primary, to run in the RDS cluster"
  type        = number
}

# See https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Aurora.Managing.html for the instance types supported by
# Aurora
variable "instance_type" {
  description = "The instance type to use for the db (e.g. db.r3.large)"
  type        = string
}


# Database configuration

variable "master_username" {
  description = "The username for the master user."
  type        = string
}

variable "master_password" {
  description = "The password for the master user."
  type        = string
}

variable "port" {
  description = "The port the DB will listen on (e.g. 3306)"
  type        = number
}


# Network configuration

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy Aurora."
  type        = string
}

variable "aurora_subnet_ids" {
  description = "The list of IDs of the subnets in which to deploy Aurora. The list must only contain subnets in var.vpc_id."
  type        = list(string)
}

variable "allow_connections_from_cidr_blocks" {
  description = "The list of network CIDR blocks to allow network access to Aurora from. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = list(string)
}

variable "allow_connections_from_security_groups" {
  description = "The list of IDs or Security Groups to allow network access to Aurora from. All security groups must either be in the VPC specified by var.vpc_id, or a peered VPC with the VPC specified by var.vpc_id. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = list(string)
}


# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "db_name" {
  description = "The name for your database of up to 8 alpha-numeric characters. If you do not provide a name, Amazon RDS will not create a database in the DB cluster you are creating."
  type        = string
  default     = null
}

variable "engine" {
  description = "The name of the database engine to be used for the RDS instance. Must be one of: aurora, aurora-postgresql."
  type        = string
  default     = "aurora"
}

# Note: you cannot enable encryption on an existing DB, so you have to enable it for the very first deployment. If you
# already created the DB unencrypted, you'll have to create a new one with encryption enabled and migrate your data to
# it. For more info on RDS encryption, see: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.Encryption.html
variable "storage_encrypted" {
  description = "Specifies whether the DB cluster uses encryption for data at rest in the underlying storage for the DB, its automated backups, Read Replicas, and snapshots. Uses the default aws/rds key in KMS."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "The ARN of a KMS key that should be used to encrypt data on disk. Only used if var.storage_encrypted is true. If you leave this null, the default RDS KMS key for the account will be used."
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "How many days to keep backup snapshots around before cleaning them up. Max: 35"
  type        = number
  default     = 30
}

# By default, only apply changes during the scheduled maintenance window, as certain DB changes cause degraded
# performance or downtime. For more info, see:
# http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Modifying.html
variable "apply_immediately" {
  description = "Specifies whether any cluster modifications are applied immediately, or during the next maintenance window. Note that cluster modifications may cause degraded performance or downtime."
  type        = bool
  default     = false
}


# Cross account snapshot settings

variable "share_snapshot_with_another_account" {
  description = "If set to true, take periodic snapshots of the Aurora DB that should be shared with another account."
  type        = bool
  default     = false
}

variable "share_snapshot_with_account_id" {
  description = "The ID of the AWS Account that the snapshot should be shared with. Required if var.share_snapshot_with_another_account is true."
  type        = string
  default     = null
}

variable "share_snapshot_schedule_expression" {
  description = "An expression that defines how often to run the lambda function to take snapshots for the purpose of cross account sharing. For example, cron(0 20 * * ? *) or rate(5 minutes). Required if var.share_snapshot_with_another_account is true"
  type        = string
  default     = null
}

variable "share_snapshot_max_snapshots" {
  description = "The maximum number of snapshots to keep around for the purpose of cross account sharing. Once this number is exceeded, a lambda function will delete the oldest snapshots. Only used if var.share_snapshot_with_another_account is true."
  type        = number
  default     = 30
}

variable "enable_share_snapshot_cloudwatch_alarms" {
  description = "When true, enable CloudWatch alarms for the manual snapshots created for the purpose of sharing with another account. Only used if var.share_snapshot_with_another_account is true."
  type        = bool
  default     = true
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
  description = "The ARNs of SNS topics where CloudWatch alarms (e.g., for CPU, memory, and disk space usage) should send notifications. Also used for the alarms if the share snapshot backup job fails."
  type        = list(string)
  default     = []
}

variable "too_many_db_connections_threshold" {
  description = "Trigger an alarm if the number of connections to the DB instance goes above this threshold."
  type        = number

  # The max number of connections allowed by RDS depends a) the type of DB, b) the DB instance type, and c) the
  # use case, and it can vary from ~30 all the way up to 5,000, so we cannot pick a reasonable default here.
  default = null
}

variable "high_cpu_utilization_threshold" {
  description = "Trigger an alarm if the DB instance has a CPU utilization percentage above this threshold."
  type        = number
  default     = 90
}

variable "high_cpu_utilization_period" {
  description = "The period, in seconds, over which to measure the CPU utilization percentage."
  type        = number
  default     = 60
}

variable "low_memory_available_threshold" {
  description = "Trigger an alarm if the amount of free memory, in Bytes, on the DB instance drops below this threshold."
  type        = number

  # Default is 100MB (100 million bytes)
  default = 100000000
}

variable "low_memory_available_period" {
  description = "The period, in seconds, over which to measure the available free memory."
  type        = number
  default     = 60
}

variable "low_disk_space_available_threshold" {
  description = "Trigger an alarm if the amount of disk space, in Bytes, on the DB instance drops below this threshold."
  type        = number

  # Default is 1GB (1 billion bytes)
  default = 1000000000
}

variable "low_disk_space_available_period" {
  description = "The period, in seconds, over which to measure the available free disk space."
  type        = number
  default     = 60
}

variable "enable_perf_alarms" {
  description = "Set to true to enable alarms related to performance, such as read and write latency alarms. Set to false to disable those alarms if you aren't sure what would be reasonable perf numbers for your RDS set up or if those numbers are too unpredictable."
  type        = bool
  default     = true
}

variable "high_read_latency_threshold" {
  description = "Trigger an alarm if the DB instance read latency (average amount of time taken per disk I/O operation), in seconds, is above this threshold."
  type        = number
  default     = 5
}

variable "high_read_latency_period" {
  description = "The period, in seconds, over which to measure the read latency."
  type        = number
  default     = 60
}

variable "high_write_latency_threshold" {
  description = "Trigger an alarm if the DB instance write latency (average amount of time taken per disk I/O operation), in seconds, is above this threshold."
  type        = number
  default     = 5
}

variable "high_write_latency_period" {
  description = "The period, in seconds, over which to measure the write latency."
  type        = number
  default     = 60
}

variable "create_snapshot_cloudwatch_metric_namespace" {
  description = "The namespace to use for the CloudWatch metric we report every time a new RDS snapshot is created. We add a CloudWatch alarm on this metric to notify us if the backup job fails to run for any reason. Defaults to the cluster name."
  type        = string
  default     = null
}

variable "backup_job_alarm_period" {
  description = "How often, in seconds, the backup job is expected to run. This is the same as var.schedule_expression, but unfortunately, Terraform offers no way to convert rate expressions to seconds. We add a CloudWatch alarm that triggers if the metric in var.create_snapshot_cloudwatch_metric_namespace isn't updated within this time period, as that indicates the backup failed to run."
  type        = number

  # Default to hourly
  default = 3600
}
