# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN AURORA RDS CLUSTER
# This module can be used to deploy an Amazon Aurora RDS Cluster. It creates the following resources:
#
# - An RDS Aurora cluster with a primary instance and replicas.
# - CloudWatch alarms for monitoring performance issues with the RDS cluster
# - A suite of lambda functions to periodically take cross account snapshots of the database.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6, < 4.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE AURORA RDS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/aurora?ref=v0.22.4"

  name                        = var.name
  port                        = local.port
  engine                      = local.engine
  engine_mode                 = var.engine_mode
  engine_version              = var.engine_version
  custom_tags                 = var.custom_tags
  allow_major_version_upgrade = var.allow_major_version_upgrade

  deletion_protection = var.enable_deletion_protection

  instance_count = var.instance_count
  instance_type  = var.instance_type

  db_cluster_parameter_group_name  = local.use_custom_cluster_parameter_group ? aws_rds_cluster_parameter_group.custom[0].name : null
  db_instance_parameter_group_name = local.use_custom_instance_parameter_group ? aws_db_parameter_group.custom[0].name : null

  scaling_configuration_auto_pause               = var.scaling_configuration_auto_pause
  scaling_configuration_max_capacity             = var.scaling_configuration_max_capacity
  scaling_configuration_min_capacity             = var.scaling_configuration_min_capacity
  scaling_configuration_seconds_until_auto_pause = var.scaling_configuration_seconds_until_auto_pause

  db_name         = local.db_name
  master_username = local.master_username
  master_password = local.master_password

  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.aurora_subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  backup_retention_period             = var.backup_retention_period
  kms_key_arn                         = var.kms_key_arn
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  apply_immediately                   = var.apply_immediately
  enabled_cloudwatch_logs_exports     = var.enabled_cloudwatch_logs_exports

  storage_encrypted = var.storage_encrypted

  # These are dangerous variables that exposed to make testing easier, but should be left untouched.
  publicly_accessible = var.publicly_accessible
  skip_final_snapshot = var.skip_final_snapshot

  # Create DB instance from snapshot backup if var.snapshot_identifier is set
  snapshot_identifier = var.snapshot_identifier
}

resource "aws_rds_cluster_parameter_group" "custom" {
  count = local.use_custom_cluster_parameter_group ? 1 : 0

  name   = var.db_cluster_custom_parameter_group.name
  family = var.db_cluster_custom_parameter_group.family
  tags   = var.custom_tags

  dynamic "parameter" {
    for_each = var.db_cluster_custom_parameter_group.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}

resource "aws_db_parameter_group" "custom" {
  count = local.use_custom_instance_parameter_group ? 1 : 0

  name   = var.db_instance_custom_parameter_group.name
  family = var.db_instance_custom_parameter_group.family
  tags   = var.custom_tags

  dynamic "parameter" {
    for_each = var.db_instance_custom_parameter_group.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}

locals {
  use_custom_cluster_parameter_group  = var.db_cluster_custom_parameter_group != null
  use_custom_instance_parameter_group = var.db_instance_custom_parameter_group != null

  # The primary_endpoint is of the format <host>:<port>. This output returns just the host part.
  primary_host = split(":", module.database.cluster_endpoint)[0]

  # The config data below can be provided in either a variable or from AWS Secrets Manager
  # The variable value is read first. If null, we will read  the values from the secrets manager
  # in JSON, as described here:
  #
  #   https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html
  #
  #
  db_config       = var.db_config_secrets_manager_id != null ? jsondecode(data.aws_secretsmanager_secret_version.db_config[0].secret_string) : null
  engine          = var.engine != null ? var.engine : nonsensitive(local.db_config.engine)
  port            = var.port != null ? var.port : nonsensitive(local.db_config.port)
  db_name         = var.db_name != null ? var.db_name : nonsensitive(local.db_config.dbname)
  master_username = var.master_username != null ? var.master_username : nonsensitive(local.db_config.username)
  master_password = var.master_password != null ? var.master_password : local.db_config.password
}

data "aws_secretsmanager_secret_version" "db_config" {
  count     = var.db_config_secrets_manager_id != null ? 1 : 0
  secret_id = var.db_config_secrets_manager_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE AURORA CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "rds_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/rds-alarms?ref=v0.32.0"
  create_resources = var.enable_cloudwatch_alarms && var.engine_mode == "provisioned"

  rds_instance_ids     = module.database.instance_ids
  num_rds_instance_ids = var.instance_count
  is_aurora            = true
  alarm_sns_topic_arns = var.alarms_sns_topic_arns

  too_many_db_connections_threshold  = var.too_many_db_connections_threshold
  high_cpu_utilization_threshold     = var.high_cpu_utilization_threshold
  high_cpu_utilization_period        = var.high_cpu_utilization_period
  low_memory_available_threshold     = var.low_memory_available_threshold
  low_memory_available_period        = var.low_memory_available_period
  low_disk_space_available_threshold = var.low_disk_space_available_threshold
  low_disk_space_available_period    = var.low_disk_space_available_period

  enable_perf_alarms           = var.enable_perf_alarms
  high_read_latency_threshold  = var.high_read_latency_threshold
  high_read_latency_period     = var.high_read_latency_period
  high_write_latency_threshold = var.high_write_latency_threshold
  high_write_latency_period    = var.high_write_latency_period
}


# ---------------------------------------------------------------------------------------------------------------------
# SET UP LAMBDA FUNCTIONS FOR CROSS ACCOUNT SNAPSHOT SHARING
# Since the automatic snapshots of RDS does not support natively sharing snapshots cross account, we set up multiple
# lambda functions that manually create and share snapshots for this purpose.
# ---------------------------------------------------------------------------------------------------------------------

# Lambda function that runs on a specified schedule to manually create the DB snapshot.
module "create_snapshot" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/lambda-create-snapshot?ref=v0.22.4"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.cluster_id
  rds_db_arn               = module.database.cluster_arn
  rds_db_is_aurora_cluster = true

  schedule_expression = var.share_snapshot_schedule_expression

  # Automatically share the snapshots with the AWS account in var.share_snapshot_with_account_id
  share_snapshot_with_another_account = true
  share_snapshot_lambda_arn           = module.share_snapshot.lambda_function_arn
  share_snapshot_with_account_id      = var.share_snapshot_with_account_id

  # Report a custom CloudWatch metric every time we create a snapshot. We add an alarm on this metric to notify us if
  # this backup job fails to run for some reason.
  report_cloudwatch_metric           = var.enable_cloudwatch_metrics
  report_cloudwatch_metric_namespace = local.create_snapshot_cloudwatch_metric_namespace
  report_cloudwatch_metric_name      = "${module.database.cluster_id}-create-snapshot"
}

# Lambda function that will share the snapshots made using `create_snapshot`.
module "share_snapshot" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/lambda-share-snapshot?ref=v0.22.4"
  create_resources = var.share_snapshot_with_another_account

  rds_db_arn = module.database.cluster_arn
  name       = "${var.name}-share-snapshot"
}

# Lambda function that periodically culls old snapshots.
module "cleanup_snapshots" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/lambda-cleanup-snapshots?ref=v0.22.4"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.cluster_id
  rds_db_arn               = module.database.cluster_arn
  rds_db_is_aurora_cluster = true

  schedule_expression = var.share_snapshot_schedule_expression
  max_snapshots       = var.share_snapshot_max_snapshots
}

# CloudWatch alarm that goes off if the backup job fails to create a new snapshot.
module "backup_job_alarm" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/scheduled-job-alarm?ref=v0.32.0"
  create_resources = var.share_snapshot_with_another_account && var.enable_cloudwatch_alarms

  name                 = "${var.name}-create-snapshot-failed"
  namespace            = local.create_snapshot_cloudwatch_metric_namespace
  metric_name          = "${module.database.cluster_id}-create-snapshot"
  period               = var.backup_job_alarm_period
  alarm_sns_topic_arns = var.alarms_sns_topic_arns
}

locals {
  create_snapshot_cloudwatch_metric_namespace = var.create_snapshot_cloudwatch_metric_namespace != null ? var.create_snapshot_cloudwatch_metric_namespace : var.name
}


# ---------------------------------------------------------------------------------------------------------------------
# SET UP WIDGETS FOR CLOUDWATCH DASHBOARD
# ---------------------------------------------------------------------------------------------------------------------

module "metric_widget_aurora_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.32.0"

  title = "${var.name} Aurora CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = [
    ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.name]
  ]
}

module "metric_widget_aurora_memory" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.32.0"

  title = "${var.name} Aurora FreeableMemory"
  stat  = "Minimum"

  period = var.dashboard_memory_widget_parameters.period
  width  = var.dashboard_memory_widget_parameters.width
  height = var.dashboard_memory_widget_parameters.height

  metrics = [
    ["AWS/RDS", "FreeableMemory", "DBClusterIdentifier", var.name]
  ]
}

module "metric_widget_aurora_disk_space" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.32.0"

  title = "${var.name} Aurora Volume Bytes Available"
  stat  = "Minimum"

  period = var.dashboard_disk_space_widget_parameters.period
  width  = var.dashboard_disk_space_widget_parameters.width
  height = var.dashboard_disk_space_widget_parameters.height

  metrics = [
    ["AWS/RDS", "AuroraVolumeBytesLeftTotal", "DBClusterIdentifier", var.name]
  ]
}

module "metric_widget_aurora_db_connections" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.32.0"

  title = "${var.name} Aurora DatabaseConnections"
  stat  = "Maximum"

  period = var.dashboard_db_connections_widget_parameters.period
  width  = var.dashboard_db_connections_widget_parameters.width
  height = var.dashboard_db_connections_widget_parameters.height

  metrics = [
    ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.name]
  ]
}

module "metric_widget_aurora_read_latency" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.32.0"

  title = "${var.name} Aurora ReadLatency"
  stat  = "Average"

  period = var.dashboard_read_latency_widget_parameters.period
  width  = var.dashboard_read_latency_widget_parameters.width
  height = var.dashboard_read_latency_widget_parameters.height

  metrics = [
    ["AWS/RDS", "ReadLatency", "DBClusterIdentifier", var.name]
  ]
}

module "metric_widget_aurora_write_latency" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.32.0"

  title = "${var.name} Aurora WriteLatency"
  stat  = "Average"

  period = var.dashboard_write_latency_widget_parameters.period
  width  = var.dashboard_write_latency_widget_parameters.width
  height = var.dashboard_write_latency_widget_parameters.height

  metrics = [
    ["AWS/RDS", "WriteLatency", "DBClusterIdentifier", var.name]
  ]
}
