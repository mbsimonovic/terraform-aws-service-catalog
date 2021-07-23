# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator when calling this terraform module
# ---------------------------------------------------------------------------------------------------------------------

# Cluster configuration

variable "name" {
  description = "The name used to namespace all the Aurora resources created by these templates, including the cluster and cluster instances (e.g. drupaldb). Must be unique in this region. Must be a lowercase string."
  type        = string
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

# Database configuration

variable "port" {
  description = "The port the DB will listen on (e.g. 3306). This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id. A value here overrides the value in db_config_secrets_manager_id."
  type        = number
  default     = null
}

variable "master_username" {
  description = "The value to use for the master username of the database. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id. A value here overrides the value in db_config_secrets_manager_id."
  type        = string
  default     = null
}

variable "master_password" {
  description = "The value to use for the master password of the database. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id. A value here overrides the value in db_config_secrets_manager_id."
  type        = string
  default     = null
  sensitive   = true
}

variable "db_config_secrets_manager_id" {
  description = "The friendly name or ARN of an AWS Secrets Manager secret that contains database configuration information in the format outlined by this document: https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html. The engine, username, password, dbname, and port fields must be included in the JSON. Note that even with this precaution, this information will be stored in plaintext in the Terraform state file! See the following blog post for more details: https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1. If you do not wish to use Secrets Manager, leave this as null, and use the master_username, master_password, db_name, engine, and port variables."
  type        = string
  default     = null
  # Example JSON value for the Secrets Manager secret:
  # {
  #   "engine": "aurora",
  #   "username": "example-user",
  #   "password": "example-password",
  #   "dbname": "myDatabase",
  #   "port": "3306"
  # }
}

variable "db_name" {
  description = "The name for your database of up to 8 alpha-numeric characters. If you do not provide a name, Amazon RDS will not create a database in the DB cluster you are creating. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id. A value here overrides the value in db_config_secrets_manager_id."
  type        = string
  default     = null
}

variable "engine" {
  description = "The name of the database engine to be used for this DB cluster. Valid Values: aurora (for MySQL 5.6-compatible Aurora), aurora-mysql (for MySQL 5.7-compatible Aurora), and aurora-postgresql. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id. A value here overrides the value in db_config_secrets_manager_id."
  type        = string
  default     = null
}

variable "engine_version" {
  description = "The Amazon Aurora DB engine version for the selected engine and engine_mode. Note: Starting with Aurora MySQL 2.03.2, Aurora engine versions have the following syntax <mysql-major-version>.mysql_aurora.<aurora-mysql-version>. e.g. 5.7.mysql_aurora.2.08.1."
  type        = string
  default     = null
}

variable "allow_major_version_upgrade" {
  description = "Enable to allow major engine version upgrades when changing engine versions."
  type        = bool
  default     = false
}

variable "engine_mode" {
  description = "The version of aurora to run - provisioned or serverless."
  type        = string
  default     = "provisioned"
}

variable "db_cluster_custom_parameter_group" {
  description = "Configure a custom parameter group for the RDS DB cluster. This will create a new parameter group with the given parameters. When null, the database will be launched with the default parameter group."
  type = object({
    # Name of the parameter group to create
    name = string

    # The family of the DB cluster parameter group.
    family = string

    # The parameters to configure on the created parameter group.
    parameters = list(object({
      # Parameter name to configure.
      name = string

      # Vaue to set the parameter.
      value = string

      # When to apply the parameter. "immediate" or "pending-reboot".
      apply_method = string
    }))
  })
  default = null
}

variable "db_instance_custom_parameter_group" {
  description = "Configure a custom parameter group for the RDS DB Instance. This will create a new parameter group with the given parameters. When null, the database will be launched with the default parameter group."
  type = object({
    # Name of the parameter group to create
    name = string

    # The family of the DB cluster parameter group.
    family = string

    # The parameters to configure on the created parameter group.
    parameters = list(object({
      # Parameter name to configure.
      name = string

      # Vaue to set the parameter.
      value = string

      # When to apply the parameter. "immediate" or "pending-reboot".
      apply_method = string
    }))
  })
  default = null
}

variable "allow_connections_from_cidr_blocks" {
  description = "The list of network CIDR blocks to allow network access to Aurora from. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = list(string)
  default     = []
}

variable "allow_connections_from_security_groups" {
  description = "The list of IDs or Security Groups to allow network access to Aurora from. All security groups must either be in the VPC specified by var.vpc_id, or a peered VPC with the VPC specified by var.vpc_id. One of var.allow_connections_from_cidr_blocks or var.allow_connections_from_security_groups must be specified for the database to be reachable."
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the database instance. If this is enabled, the database cannot be deleted."
  type        = bool
  default     = false
}

# Provisioned RDS cluster setting

variable "instance_count" {
  description = "The number of DB instances, including the primary, to run in the RDS cluster. Only used when var.engine_mode is set to provisioned."
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "The instance type to use for the db (e.g. db.r3.large). Only used when var.engine_mode is set to provisioned."
  type        = string

  # See https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Aurora.Managing.html for the instance types supported by
  # Aurora
  default = "db.t3.small"
}

variable "enabled_cloudwatch_logs_exports" {
  description = "If non-empty, the Aurora cluster will export the specified logs to Cloudwatch. Must be zero or more of: audit, error, general and slowquery"
  type        = list(string)
  default     = []
}

# Serverless scaling configuration
#
# https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless.how-it-works.html#aurora-serverless.how-it-works.auto-scaling
# You can specify the minimum and maximum ACU. The minimum Aurora capacity unit is the lowest ACU to which the DB
# cluster can scale down. The maximum Aurora capacity unit is the highest ACU to which the DB cluster can scale up.
# Based on your settings, Aurora Serverless automatically creates scaling rules for thresholds for CPU utilization,
# connections, and available memory.
#
# The below max/min's are in the ACU's.  A good read on the impacts is available here:
#    https://www.jeremydaly.com/aurora-serverless-the-good-the-bad-and-the-scalable/

variable "scaling_configuration_auto_pause" {
  description = "Whether to enable automatic pause. A DB cluster can be paused only when it's idle (it has no connections). If a DB cluster is paused for more than seven days, the DB cluster might be backed up with a snapshot. In this case, the DB cluster is restored when there is a request to connect to it. Only used when var.engine_mode is set to serverless."
  type        = bool
  default     = true
}

variable "scaling_configuration_max_capacity" {
  description = "The maximum capacity. The maximum capacity must be greater than or equal to the minimum capacity. Valid capacity values are 2, 4, 8, 16, 32, 64, 128, and 256. Only used when var.engine_mode is set to serverless."
  type        = number
  default     = 256
}

variable "scaling_configuration_min_capacity" {
  description = "The minimum capacity. The minimum capacity must be lesser than or equal to the maximum capacity. Valid capacity values are 2, 4, 8, 16, 32, 64, 128, and 256. Only used when var.engine_mode is set to serverless."
  type        = number
  default     = 2
}

variable "scaling_configuration_seconds_until_auto_pause" {
  description = "The time, in seconds, before an Aurora DB cluster in serverless mode is paused. Valid values are 300 through 86400. Only used when var.engine_mode is set to serverless."
  type        = number
  default     = 300
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

variable "iam_database_authentication_enabled" {
  description = "Specifies whether mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled. Disabled by default."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "How many days to keep backup snapshots around before cleaning them up. Max: 35"
  type        = number
  default     = 30
}

# Create DB instance from a snapshot backup
variable "snapshot_identifier" {
  description = "If non-null, the RDS Instance will be restored from the given Snapshot ID. This is the Snapshot ID you'd find in the RDS console, e.g: rds:production-2015-06-26-06-05."
  type        = string
  default     = null
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

# Dashboard Settings

variable "dashboard_cpu_usage_widget_parameters" {
  description = "Parameters for the cpu usage widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_memory_widget_parameters" {
  description = "Parameters for the available memory widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_disk_space_widget_parameters" {
  description = "Parameters for the available disk space widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_db_connections_widget_parameters" {
  description = "Parameters for the database connections widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_read_latency_widget_parameters" {
  description = "Parameters for the read latency widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "dashboard_write_latency_widget_parameters" {
  description = "Parameters for the read latency widget to output for use in a CloudWatch dashboard."
  type = object({
    # The period in seconds for metrics to sample across.
    period = number

    # The width and height of the widget in grid units in a 24 column grid. E.g., a value of 12 will take up half the
    # space.
    width  = number
    height = number
  })
  default = {
    period = 60
    width  = 8
    height = 6
  }
}

variable "custom_tags" {
  description = "A map of custom tags to apply to the RDS cluster and all associated resources created for it. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
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
