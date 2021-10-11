# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AURORA RDS CLUSTER, WITH CLOUDWATCH METRICS, ALERTS, AND CROSS ACCOUNT SNAPSHOTS
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}


provider "aws" {
  region = var.aws_region
}

module "aurora" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/aurora?ref=v1.0.8"
  source = "../../../../modules/data-stores/aurora"

  name                              = var.name
  engine                            = var.engine
  engine_mode                       = var.engine_mode
  db_cluster_custom_parameter_group = var.db_cluster_custom_parameter_group

  # Database Configurations
  master_username = var.master_username
  master_password = var.master_password
  db_name         = var.db_name

  # For this example, we will auto select the default port that matches the provided engine.
  # - aurora => 3306 (default mysql port)
  # - aurora-postgresql => 5432 (default postgres port)
  port = var.engine == "aurora" ? 3306 : 5432

  db_config_secrets_manager_id = var.db_config_secrets_manager_id

  # To keep this example simple, we run it in the default VPC, put everything in the same subnets, and allow access from
  # any source. In production, you'll want to use a custom VPC, private subnets, and explicitly close off access to only
  # those applications that need it.
  vpc_id                                 = data.aws_vpc.default.id
  aurora_subnet_ids                      = data.aws_subnet_ids.default.ids
  allow_connections_from_cidr_blocks     = ["0.0.0.0/0"]
  allow_connections_from_security_groups = []

  # To make it easier to test this in CI, we expose the database publicly (if in provisioned mode). However, for regular
  # deployments, you should insulate the database in a private subnet and avoid exposing it publicly outside the VPC.
  publicly_accessible = var.engine_mode == "provisioned"

  # We also make testing easier by disabling the final snapshot. This speeds up the destroy process, but at the expense
  # of deleting all data in the Database with no backup of the state just before deletion. You should not touch this
  # variable for regular deployments and use the default, which will always take the final snapshot.
  skip_final_snapshot = true

  # Configure cross account nightly snapshot sharing.
  share_snapshot_with_another_account = true
  share_snapshot_with_account_id      = var.share_snapshot_with_account_id
  share_snapshot_schedule_expression  = "rate(1 day)"

  # To keep the example simple, all changes will be applied immediately. In production, consider setting this to `false`
  # so that changes are rolled out during preselected maintenance windows.
  apply_immediately = true
}


# ----------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDWATCH DASHBOARD WITH METRICS FOR THE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "dashboard" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard?ref=v0.30.2"

  dashboards = {
    (var.name) = [
      module.aurora.metric_widget_aurora_cpu_usage,
      module.aurora.metric_widget_aurora_memory,
      module.aurora.metric_widget_aurora_disk_space,
      module.aurora.metric_widget_aurora_db_connections,
      module.aurora.metric_widget_aurora_read_latency,
      module.aurora.metric_widget_aurora_write_latency,
    ]
  }
}