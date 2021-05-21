# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN RDS INSTANCE WITH CLOUDWATCH METRICS, ALERTS, AND CROSS ACCOUNT SNAPSHOTS
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"
}


provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# AN EXAMPLE OF A MYSQL RDS DATABASE
# ------------------------------------------------------------------------------

module "mysql_rds" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/rds?ref=v1.0.8"
  source = "../../../../modules/data-stores/rds"

  name                   = local.cluster_name
  db_name                = var.db_name
  port                   = var.port
  engine                 = var.engine
  engine_version         = "8.0.17"
  custom_parameter_group = var.custom_parameter_group

  master_username = var.master_username
  master_password = var.master_password

  db_config_secrets_manager_id = var.db_config_secrets_manager_id

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnet_ids.default.ids

  # To make this example simple to test, we allow incoming connections from any IP, but in real-world usage, you should
  # lock this down to the IPs of trusted servers
  allow_connections_from_cidr_blocks = ["0.0.0.0/0"]

  # To make it easier to test this in CI, we expose the database publicly. However, for regular deployments,
  # you should insulate the database in a private subnet and avoid exposing it publicly outside the VPC.
  publicly_accessible = true

  enable_cloudwatch_alarms = false

  # Since this is just an example, we are using a small DB instance with only 10GB of storage, no standby, no replicas,
  # and no automatic backups. You'll want to tweak all of these settings for production usage.
  instance_type = "db.t3.micro"

  allocated_storage       = 10
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
}

locals {
  cluster_name = "${var.name}-mysql"
}


# ----------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDWATCH DASHBOARD WITH METRICS FOR THE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "dashboard" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/metrics/cloudwatch-dashboard?ref=v0.20.0"

  dashboards = {
    (local.cluster_name) = [
      module.mysql_rds.metric_widget_rds_cpu_usage,
      module.mysql_rds.metric_widget_rds_memory,
      module.mysql_rds.metric_widget_rds_disk_space,
      module.mysql_rds.metric_widget_rds_db_connections,
      module.mysql_rds.metric_widget_rds_read_latency,
      module.mysql_rds.metric_widget_rds_write_latency,
    ]
  }
}