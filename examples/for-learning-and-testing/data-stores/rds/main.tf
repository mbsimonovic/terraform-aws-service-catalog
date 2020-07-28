# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN RDS INSTANCE WITH CLOUDWATCH METRICS, ALERTS, AND CROSS ACCOUNT SNAPSHOTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# AN EXAMPLE OF A MYSQL RDS DATABASE
# ------------------------------------------------------------------------------

module "mysql_rds" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/data-stores/rds?ref=v1.0.8"
  source = "../../../../modules/data-stores/rds"

  name           = local.cluster_name
  engine_version = "8.0.17"

  db_config_secrets_manager_id = aws_secretsmanager_secret_version.db_config.secret_id

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
  db_config = jsonencode({
    engine   = "mysql"
    port     = "3306"
    username = var.master_username
    password = var.master_password
    db_name  = var.db_name
  })
}


# ----------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDWATCH DASHBOARD WITH METRICS FOR THE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "dashboard" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard?ref=v0.20.0"

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

# ----------------------------------------------------------------------------------------------------------------------
# CREATE A SECRET IN AWS SECRETS MANAGER
# IMPORTANT: For testing purposes only! In a production context, create the secret outside of Terraform.
# See: https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1
# ----------------------------------------------------------------------------------------------------------------------

resource "random_string" "secret_id" {
  length  = 8
  special = false
}

resource "aws_secretsmanager_secret" "db_config" {
  name = "${random_string.secret_id.result}-db-config"
}

resource "aws_secretsmanager_secret" "master_password_secret" {
  name = "${random_string.secret_id.result}-rds-master-password"
}

resource "aws_secretsmanager_secret_version" "db_config" {
  secret_id     = aws_secretsmanager_secret.db_config.id
  secret_string = local.db_config
}
