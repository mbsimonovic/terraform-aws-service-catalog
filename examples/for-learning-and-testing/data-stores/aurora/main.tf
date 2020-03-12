# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AURORA RDS CLUSTER, WITH CLOUDWATCH METRICS, ALERTS, AND CROSS ACCOUNT SNAPSHOTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "aurora" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/data-stores/aurora?ref=v1.0.8"
  source = "../../../../modules/data-stores/aurora"

  name   = var.name
  engine = var.engine

  # Deploy a small cluster with one replica
  instance_count = 2
  instance_type  = "db.t3.small"

  # Database Configurations
  master_username = var.master_username
  master_password = var.master_password
  db_name         = var.db_name

  # For this example, we will auto select the default port that matches the provided engine.
  # - aurora => 3306 (default mysql port)
  # - aurora-postgresql => 5432 (default postgres port)
  port = var.engine == "aurora" ? 3306 : 5432

  # To keep this example simple, we run it in the default VPC, put everything in the same subnets, and allow access from
  # any source. In production, you'll want to use a custom VPC, private subnets, and explicitly close off access to only
  # those applications that need it.
  vpc_id                                 = data.aws_vpc.default.id
  aurora_subnet_ids                      = data.aws_subnet_ids.default.ids
  allow_connections_from_cidr_blocks     = ["0.0.0.0/0"]
  allow_connections_from_security_groups = []

  # Configure cross account nightly snapshot sharing.
  share_snapshot_with_another_account = true
  share_snapshot_with_account_id      = var.share_snapshot_with_account_id
  share_snapshot_schedule_expression  = "rate(1 day)"

  # To keep the example simple, all changes will be applied immediately. In production, consider setting this to `false`
  # so that changes are rolled out during preselected maintenance windows.
  apply_immediately = true
}
