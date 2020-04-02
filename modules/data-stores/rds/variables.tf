# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name used to namespace all the RDS resources created by these templates, including the cluster and cluster instances (e.g. mysql-stage). Must be unique in this region. Must be a lowercase string."
  type        = string
}

variable "engine" {
  description = "The DB engine to use (e.g. mysql)"
  type        = string
}

variable "engine_version" {
  description = "The version of var.engine to use (e.g. 8.0.17 for mysql)."
  type        = string
}

variable "allocated_storage" {
  description = "The amount of storage space the DB should use, in GB."
  type        = number
}

variable "master_username" {
  description = "The username for the master user."
  type        = string
}

variable "master_password" {
  description = "The password for the master user."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy RDS."
  type        = string
}

variable "subnet_ids" {
  description = "The list of IDs of the subnets in which to deploy RDS. The list must only contain subnets in var.vpc_id."
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "db_name" {
  description = "The name for your database of up to 8 alpha-numeric characters. If you do not provide a name, Amazon RDS will not create an empty database on the RDS instance."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "The instance type to use for the db (e.g. db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "allow_connections_from_cidr_blocks" {
  description = "The list of network CIDR blocks to allow network access to RDS from. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = list(string)
  default     = []
}

variable "allow_connections_from_security_groups" {
  description = "The list of IDs or Security Groups to allow network access to RDS from. All security groups must either be in the VPC specified by var.vpc_id, or a peered VPC with the VPC specified by var.vpc_id. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = list(string)
  default     = []
}

variable "multi_az" {
  description = "Specifies if a standby instance should be deployed in another availability zone. If the primary fails, this instance will automatically take over."
  type        = bool
  default     = false
}

variable "port" {
  description = "The port the DB will listen on (e.g. 3306). If not provided, will use the default for the selected engine."
  type        = number
  default     = null
}

# Monitoring settings

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to enable for exporting to CloudWatch logs. If omitted, no logs will be exported. Valid values (depending on engine): alert, audit, error, general, listener, slowquery, trace, postgresql (PostgreSQL) and upgrade (PostgreSQL)."
  type        = list(string)
  default     = []
}

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

variable "backup_retention_period" {
  description = "How many days to keep backup snapshots around before cleaning them up. Must be 1 or greater to support read replicas."
  type        = number
  default     = 30
}

variable "apply_immediately" {
  description = "Specifies whether any cluster modifications are applied immediately, or during the next maintenance window. Note that cluster modifications may cause degraded performance or downtime."
  type        = bool
  default     = false
}

variable "num_read_replicas" {
  description = "The number of read replicas to deploy"
  type        = number
  default     = 0
}

# Note: you cannot enable encryption on an existing DB, so you have to enable it for the very first deployment. If you
# already created the DB unencrypted, you'll have to create a new one with encryption enabled and migrate your data to
# it. For more info on RDS encryption, see: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.Encryption.html
variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted."
  type        = bool
  default     = true
}

variable "license_model" {
  description = "The license model to use for this DB. Check the docs for your RDS DB for available license models. Set to an empty string to use the default."
  type        = string
  default     = null
}

# Cross account snapshot settings

variable "share_snapshot_with_another_account" {
  description = "If set to true, take periodic snapshots of the RDS DB that should be shared with another account."
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

variable "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of an existing KMS customer master key (CMK) that will be used to encrypt/decrypt backup files. If null, a key will be created with permissions assigned by the following variables: cmk_administrator_iam_arns, cmk_user_iam_arns, cmk_external_user_iam_arns, allow_manage_key_permissions."
  type        = string
  default     = null
}

variable "cmk_administrator_iam_arns" {
  description = "A list of IAM ARNs for users who should be given administrator access to this CMK (e.g. arn:aws:iam::<aws-account-id>:user/<iam-user-arn>). If this list is empty, and var.kms_key_arn is null, the ARN of the current user will be used."
  type        = list(string)
  default     = []
}

variable "cmk_user_iam_arns" {
  description = "A list of IAM ARNs for users who should be given permissions to use this CMK (e.g.  arn:aws:iam::<aws-account-id>:user/<iam-user-arn>). If this list is empty, and var.kms_key_arn is null, the ARN of the current user will be used."
  type        = list(string)
  default     = []
}

variable "cmk_external_user_iam_arns" {
  description = "A list of IAM ARNs for users from external AWS accounts who should be given permissions to use this CMK (e.g. arn:aws:iam::<aws-account-id>:root)."
  type        = list(string)
  default     = []
}

variable "allow_manage_key_permissions_with_iam" {
  description = "If true, both the CMK's Key Policy and IAM Policies (permissions) can be used to grant permissions on the CMK. If false, only the CMK's Key Policy can be used to grant permissions on the CMK. False is more secure (and generally preferred), but true is more flexible and convenient."
  type        = bool
  default     = false
}
# ---------------------------------------------------------------------------------------------------------------------
# TEST PARAMETERS
# These variables exist solely for testing purposes.
# ---------------------------------------------------------------------------------------------------------------------

variable "publicly_accessible" {
  description = "If you wish to make your database accessible from the public Internet, set this flag to true (WARNING: NOT RECOMMENDED FOR REGULAR USAGE!!). The default is false, which means the database is only accessible from within the VPC, which is much more secure. This flag MUST be false for serverless mode."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted. Be very careful setting this to true; if you do, and you delete this DB instance, you will not have any backups of the data! You almost never want to set this to true, unless you are doing automated or manual testing."
  type        = bool
  default     = false
}
