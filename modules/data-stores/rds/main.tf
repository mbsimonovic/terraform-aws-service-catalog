# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN RDS DATABASE
# This module can be used to deploy an Amazon RDS database. It creates the following resources:
#
# - An RDS database  with a primary instance and replicas.
# - CloudWatch alarms for monitoring performance issues with the RDS cluster
# - A suite of lambda functions to periodically take cross account snapshots of the database.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws        = "~> 2.6"
    kubernetes = "~> 1.10"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE RDS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  source = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/rds?ref=v0.12.11"

  name           = var.name
  db_name        = var.db_name
  engine         = var.engine
  engine_version = var.engine_version
  port           = var.port
  license_model  = var.license_model

  master_username = var.master_username
  master_password = var.master_password

  # Run in the private persistence subnets and only allow incoming connections from the private app subnets
  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  instance_type     = var.instance_type
  allocated_storage = var.allocated_storage
  num_read_replicas = var.num_read_replicas

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  storage_encrypted = var.storage_encrypted
  kms_key_arn       = var.kms_key_arn

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  apply_immediately       = var.apply_immediately

  # These are dangerous variables that exposed to make testing easier, but should be left untouched.
  publicly_accessible = var.publicly_accessible
  skip_final_snapshot = var.skip_final_snapshot
}


# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE RDS INSTANCES
# ---------------------------------------------------------------------------------------------------------------------

module "rds_alarms" {
  source           = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/rds-alarms?ref=v0.19.0"
  create_resources = var.enable_cloudwatch_alarms

  rds_instance_ids     = local.rds_database_ids
  num_rds_instance_ids = 1 + var.num_read_replicas
  alarm_sns_topic_arns = var.alarms_sns_topic_arns

  too_many_db_connections_threshold  = var.too_many_db_connections_threshold
  high_cpu_utilization_threshold     = var.high_cpu_utilization_threshold
  high_cpu_utilization_period        = var.high_cpu_utilization_period
  low_memory_available_threshold     = var.low_memory_available_threshold
  low_memory_available_period        = var.low_memory_available_period
  low_disk_space_available_threshold = var.low_disk_space_available_threshold
  low_disk_space_available_period    = var.low_disk_space_available_period
  enable_perf_alarms                 = var.enable_perf_alarms
}

module "metric_widget_rds_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.19.0"

  period = 60
  stat   = "Average"
  title  = "${title(var.engine)} CPUUtilization"

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_memory" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.19.0"

  period = 60
  stat   = "Minimum"
  title  = "${title(var.engine)} FreeableMemory"

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_disk_space" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.19.0"

  period = 60
  stat   = "Minimum"
  title  = "${title(var.engine)} FreeStorageSpace"

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_db_connections" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.19.0"

  period = 60
  stat   = "Maximum"
  title  = "${title(var.engine)} DatabaseConnections"

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_read_latency" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.19.0"

  period = 60
  stat   = "Average"
  title  = "${title(var.engine)} ReadLatency"

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_write_latency" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.19.0"

  period = 60
  stat   = "Average"
  title  = "${title(var.engine)} WriteLatency"

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "WriteLatency", "DBInstanceIdentifier", id]
  ]
}

locals {
  rds_database_ids = concat([module.database.primary_id], module.database.read_replica_ids)
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP LAMBDA FUNCTIONS FOR CROSS ACCOUNT SNAPSHOT SHARING
# Since the automatic snapshots of RDS does not support natively sharing snapshots cross account, we set up multiple
# lambda functions that manually create and share snapshots for this purpose.
# ---------------------------------------------------------------------------------------------------------------------

# Lambda function that runs on a specified schedule to manually create the DB snapshot.
module "create_snapshot" {
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-create-snapshot?ref=v0.12.9"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.primary_id
  rds_db_arn               = module.database.primary_arn
  rds_db_is_aurora_cluster = false

  schedule_expression = var.share_snapshot_schedule_expression

  # Automatically share the snapshots with the AWS account in var.backup_account_id
  share_snapshot_with_another_account = true
  share_snapshot_lambda_arn           = module.share_snapshot.lambda_function_arn
  share_snapshot_with_account_id      = var.share_snapshot_with_account_id

  # Report a custom CloudWatch metric every time we create a snapshot. We add an alarm on this metric to notify us if
  # this backup job fails to run for some reason.
  report_cloudwatch_metric           = var.enable_cloudwatch_metrics
  report_cloudwatch_metric_namespace = local.create_snapshot_cloudwatch_metric_namespace
  report_cloudwatch_metric_name      = "${module.database.primary_id}-create-snapshot"
}

# Lambda function that will share the snapshots made using `create_snapshot`.
module "share_snapshot" {
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-share-snapshot?ref=v0.12.9"
  create_resources = var.share_snapshot_with_another_account

  rds_db_arn = module.database.primary_arn
  name       = "${var.name}-share-snapshot"
}

# Lambda function that periodically culls old snapshots.
module "cleanup_snapshots" {
  source           = "git::git@github.com:gruntwork-io/module-data-storage.git//modules/lambda-cleanup-snapshots?ref=v0.12.9"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.primary_id
  rds_db_arn               = module.database.primary_arn
  rds_db_is_aurora_cluster = false

  schedule_expression = var.share_snapshot_schedule_expression
  max_snapshots       = var.share_snapshot_max_snapshots
}

# CloudWatch alarm that goes off if the backup job fails to create a new snapshot.
module "backup_job_alarm" {
  source           = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/scheduled-job-alarm?ref=v0.19.0"
  create_resources = var.share_snapshot_with_another_account && var.enable_cloudwatch_alarms

  name                 = "${var.name}-create-snapshot-failed"
  namespace            = local.create_snapshot_cloudwatch_metric_namespace
  metric_name          = "${module.database.primary_id}-create-snapshot"
  period               = var.backup_job_alarm_period
  alarm_sns_topic_arns = var.alarms_sns_topic_arns
}

locals {
  create_snapshot_cloudwatch_metric_namespace = var.create_snapshot_cloudwatch_metric_namespace != null ? var.create_snapshot_cloudwatch_metric_namespace : var.name
}
# ---------------------------------------------------------------------------------------------------------------------
# KMS Customer Master Key
# Create a new KMS CMK if an existing KMS key has not been provided in var.kms_key_arn
# ---------------------------------------------------------------------------------------------------------------------

module "kms_cmk" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/kms-master-key?ref=v0.27.1"
  customer_master_keys = (
    var.kms_key_arn == null
    ? {
      (var.name) = {
        cmk_administrator_iam_arns = local.cmk_administrator_iam_arns
        cmk_user_iam_arns          = local.cmk_user_iam_arns
        cmk_external_user_iam_arns = var.cmk_external_user_iam_arns

        # The IAM role of the OpenVPN server needs access to use the KMS key, and those permissions are managed with IAM
        allow_manage_key_permissions_with_iam = true
      }
    }
    : {}
  )
}

locals {
  kms_key_arn                = var.kms_key_arn != null ? var.kms_key_arn : module.kms_cmk.key_arn[var.name]
  cmk_administrator_iam_arns = length(var.cmk_administrator_iam_arns) == 0 ? [data.aws_caller_identity.current.arn] : var.cmk_administrator_iam_arns
  cmk_user_iam_arns          = length(var.cmk_user_iam_arns) == 0 ? [data.aws_caller_identity.current.arn] : var.cmk_user_iam_arns
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP KUBERNETES SERVICE FOR SERVICE DISCOVERY
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_service" "rds" {
  count = var.create_kubernetes_service ? 1 : 0

  metadata {
    name      = var.name
    namespace = var.kubernetes_namespace
  }

  spec {
    type          = "ExternalName"
    external_name = local.primary_host
    port {
      port = var.port
    }
  }
}

locals {
  # The primary_endpoint is of the format <host>:<port>.
  primary_host = element(split(":", module.database.primary_endpoint), 0)
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
