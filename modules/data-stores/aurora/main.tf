# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN AURORA RDS CLUSTER
# This module can be used to deploy an Amazon Aurora RDS Cluster. It creates the following resources:
#
# - An RDS Aurora cluster with a primary instance and replicas.
# - CloudWatch alarms for monitoring performance issues with the RDS cluster
# - A suite of lambda functions to periodically take cross account snapshots of the database.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE AURORA RDS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  # TODO: update to released version when ready
  source = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/aurora?ref=yori-lambda-create-resources"

  name   = var.name
  port   = var.port
  engine = var.engine

  instance_count = var.instance_count
  instance_type  = var.instance_type

  db_name         = var.db_name
  master_username = var.master_username
  master_password = var.master_password

  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.aurora_subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  storage_encrypted = var.storage_encrypted
  kms_key_arn       = var.kms_key_arn

  backup_retention_period = var.backup_retention_period
  apply_immediately       = var.apply_immediately
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE AURORA CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "rds_alarms" {
  source           = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/rds-alarms?ref=v0.19.0"
  create_resources = var.enable_cloudwatch_alarms

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
  # TODO: update to released version when ready
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-create-snapshot?ref=yori-lambda-create-resources"
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
  # TODO: update to released version when ready
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-share-snapshot?ref=yori-lambda-create-resources"
  create_resources = var.share_snapshot_with_another_account

  rds_db_arn = module.database.cluster_arn
  name       = "${var.name}-share-snapshot"
}

# Lambda function that periodically culls old snapshots.
module "cleanup_snapshots" {
  # TODO: update to released version when ready
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-cleanup-snapshots?ref=yori-lambda-create-resources"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.cluster_id
  rds_db_arn               = module.database.cluster_arn
  rds_db_is_aurora_cluster = true

  schedule_expression = var.share_snapshot_schedule_expression
  max_snapshots       = var.share_snapshot_max_snapshots
}

# CloudWatch alarm that goes off if the backup job fails to create a new snapshot.
module "backup_job_alarm" {
  source           = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/scheduled-job-alarm?ref=v0.19.0"
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
