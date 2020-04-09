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
  engine         = "mysql"
  engine_version = "8.0.17"
  port           = 3306

  master_username = var.master_username
  master_password = var.master_password

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

  db_name                 = var.db_name
  allocated_storage       = 10
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true

  # Configurations for creating a Service to route to the DB.
  create_kubernetes_service = var.create_kubernetes_service
  kubernetes_namespace      = var.kubernetes_namespace
}

locals {
  cluster_name = "${var.name}-mysql"
}
