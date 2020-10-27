# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN AURORA RDS CLUSTER
# This module can be used to deploy an Amazon Aurora RDS Cluster. It creates the following resources:
#
# - An RDS Aurora cluster with a primary instance and replicas.
# - CloudWatch alarms for monitoring performance issues with the RDS cluster
# - A suite of lambda functions to periodically take cross account snapshots of the database.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.13.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.13.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE AURORA RDS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  source = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/aurora?ref=v0.16.2"

  name        = var.name
  port        = var.port
  engine      = var.engine
  engine_mode = var.engine_mode

  instance_count = var.instance_count
  instance_type  = var.instance_type

  scaling_configuration_auto_pause               = var.scaling_configuration_auto_pause
  scaling_configuration_max_capacity             = var.scaling_configuration_max_capacity
  scaling_configuration_min_capacity             = var.scaling_configuration_min_capacity
  scaling_configuration_seconds_until_auto_pause = var.scaling_configuration_seconds_until_auto_pause

  db_name         = var.db_name
  master_username = var.master_username
  master_password = var.master_password

  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.aurora_subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  backup_retention_period             = var.backup_retention_period
  kms_key_arn                         = var.kms_key_arn
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  apply_immediately                   = var.apply_immediately

  # These values have the same defaults in the module, but we hard code the configuration here for documentation purposes.
  storage_encrypted = true

  # These are dangerous variables that exposed to make testing easier, but should be left untouched.
  publicly_accessible = var.publicly_accessible
  skip_final_snapshot = var.skip_final_snapshot
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE AURORA CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "rds_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/rds-alarms?ref=v0.23.1"
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
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-create-snapshot?ref=v0.16.2"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.cluster_id
  rds_db_arn               = module.database.cluster_arn
  rds_db_is_aurora_cluster = true

  schedule_expression = var.share_snapshot_schedule_expression

  # Automatically share the snapshots with the AWS account in var.backup_account_id
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
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-share-snapshot?ref=v0.16.2"
  create_resources = var.share_snapshot_with_another_account

  rds_db_arn = module.database.cluster_arn
  name       = "${var.name}-share-snapshot"
}

# Lambda function that periodically culls old snapshots.
module "cleanup_snapshots" {
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-cleanup-snapshots?ref=v0.16.2"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.cluster_id
  rds_db_arn               = module.database.cluster_arn
  rds_db_is_aurora_cluster = true

  schedule_expression = var.share_snapshot_schedule_expression
  max_snapshots       = var.share_snapshot_max_snapshots
}

# CloudWatch alarm that goes off if the backup job fails to create a new snapshot.
module "backup_job_alarm" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/scheduled-job-alarm?ref=v0.23.1"
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.1"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.1"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.1"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.1"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.1"

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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.23.1"

  title = "${var.name} Aurora WriteLatency"
  stat  = "Average"

  period = var.dashboard_write_latency_widget_parameters.period
  width  = var.dashboard_write_latency_widget_parameters.width
  height = var.dashboard_write_latency_widget_parameters.height

  metrics = [
    ["AWS/RDS", "WriteLatency", "DBClusterIdentifier", var.name]
  ]
}
