# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN RDS DATABASE
# This module can be used to deploy an Amazon RDS database. It creates the following resources:
#
# - An RDS database  with a primary instance and replicas.
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
# DEPLOY THE RDS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/rds?ref=v0.22.4"

  name                 = var.name
  db_name              = local.db_name
  engine               = local.engine
  engine_version       = var.engine_version
  port                 = local.port
  license_model        = var.license_model
  custom_tags          = var.custom_tags
  parameter_group_name = local.use_custom_parameter_group ? aws_db_parameter_group.custom[0].name : null

  deletion_protection = var.enable_deletion_protection

  master_username = local.master_username
  master_password = local.master_password

  # Run in the private persistence subnets and only allow incoming connections from the private app subnets
  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  instance_type         = var.instance_type
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  num_read_replicas     = var.num_read_replicas

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  storage_encrypted                   = var.storage_encrypted
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  kms_key_arn                         = local.kms_key_arn

  multi_az                        = var.multi_az
  backup_window                   = var.backup_window
  backup_retention_period         = var.backup_retention_period
  replica_backup_retention_period = var.replica_backup_retention_period
  apply_immediately               = var.apply_immediately
  delete_automated_backups        = var.delete_automated_backups

  # These are dangerous variables that exposed to make testing easier, but should be left untouched.
  publicly_accessible = var.publicly_accessible
  skip_final_snapshot = var.skip_final_snapshot

  # Create DB instance from snapshot backup if var.snapshot_identifier is set
  snapshot_identifier = var.snapshot_identifier
}

resource "aws_db_parameter_group" "custom" {
  count = local.use_custom_parameter_group ? 1 : 0

  name   = var.custom_parameter_group.name
  family = var.custom_parameter_group.family
  tags   = var.custom_tags

  dynamic "parameter" {
    for_each = var.custom_parameter_group.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }
}

locals {
  use_custom_parameter_group = var.custom_parameter_group != null

  # The primary_endpoint is of the format <host>:<port>. This output returns just the host part.
  primary_host = split(":", module.database.primary_endpoint)[0]

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
# ADD CLOUDWATCH ALARMS FOR THE RDS INSTANCES
# ---------------------------------------------------------------------------------------------------------------------

module "rds_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/rds-alarms?ref=v0.30.5"
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.name} ${title(local.engine)} CPUUtilization"
  stat  = "Average"

  period = var.dashboard_cpu_usage_widget_parameters.period
  width  = var.dashboard_cpu_usage_widget_parameters.width
  height = var.dashboard_cpu_usage_widget_parameters.height

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_memory" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.name} ${title(local.engine)} FreeableMemory"
  stat  = "Minimum"

  period = var.dashboard_memory_widget_parameters.period
  width  = var.dashboard_memory_widget_parameters.width
  height = var.dashboard_memory_widget_parameters.height

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_disk_space" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.name} ${title(local.engine)} FreeStorageSpace"
  stat  = "Minimum"

  period = var.dashboard_disk_space_widget_parameters.period
  width  = var.dashboard_disk_space_widget_parameters.width
  height = var.dashboard_disk_space_widget_parameters.height

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_db_connections" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.name} ${title(local.engine)} DatabaseConnections"
  stat  = "Maximum"

  period = var.dashboard_db_connections_widget_parameters.period
  width  = var.dashboard_db_connections_widget_parameters.width
  height = var.dashboard_db_connections_widget_parameters.height

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_read_latency" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.name} ${title(local.engine)} ReadLatency"
  stat  = "Average"

  period = var.dashboard_read_latency_widget_parameters.period
  width  = var.dashboard_read_latency_widget_parameters.width
  height = var.dashboard_read_latency_widget_parameters.height

  metrics = [
    for id in local.rds_database_ids : ["AWS/RDS", "ReadLatency", "DBInstanceIdentifier", id]
  ]
}

module "metric_widget_rds_write_latency" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref=v0.30.5"

  title = "${var.name} ${title(local.engine)} WriteLatency"
  stat  = "Average"

  period = var.dashboard_write_latency_widget_parameters.period
  width  = var.dashboard_write_latency_widget_parameters.width
  height = var.dashboard_write_latency_widget_parameters.height

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
  source           = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/lambda-create-snapshot?ref=v0.22.4"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.primary_id
  rds_db_arn               = module.database.primary_arn
  rds_db_is_aurora_cluster = false

  schedule_expression = var.share_snapshot_schedule_expression

  # Automatically share the snapshots with the AWS account in var.share_snapshot_with_account_id
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
  source           = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/lambda-share-snapshot?ref=v0.22.4"
  create_resources = var.share_snapshot_with_another_account

  rds_db_arn = module.database.primary_arn
  name       = "${var.name}-share-snapshot"
}

# Lambda function that periodically culls old snapshots.
module "cleanup_snapshots" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-data-storage.git//modules/lambda-cleanup-snapshots?ref=v0.22.4"
  create_resources = var.share_snapshot_with_another_account

  rds_db_identifier        = module.database.primary_id
  rds_db_arn               = module.database.primary_arn
  rds_db_is_aurora_cluster = false

  schedule_expression = var.share_snapshot_schedule_expression
  max_snapshots       = var.share_snapshot_max_snapshots
}

# CloudWatch alarm that goes off if the backup job fails to create a new snapshot.
module "backup_job_alarm" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/scheduled-job-alarm?ref=v0.30.5"
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
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/kms-master-key?ref=v0.62.1"
  customer_master_keys = (
    var.create_custom_kms_key
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
  kms_key_arn                = var.create_custom_kms_key ? module.kms_cmk.key_arn[var.name] : var.kms_key_arn
  cmk_administrator_iam_arns = length(var.cmk_administrator_iam_arns) == 0 ? [data.aws_caller_identity.current.arn] : var.cmk_administrator_iam_arns
  cmk_user_iam_arns          = length(var.cmk_user_iam_arns) == 0 ? [{ name = [data.aws_caller_identity.current.arn], conditions = [] }] : var.cmk_user_iam_arns
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
