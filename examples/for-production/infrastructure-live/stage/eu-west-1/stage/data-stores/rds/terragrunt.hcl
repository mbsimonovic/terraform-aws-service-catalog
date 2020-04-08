# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/data-stores/rds?ref=master"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Pull in outputs from these modules to compute inputs. These modules will also be added to the dependency list for
# xxx-all commands.
dependency "vpc" {
  config_path = "../../networking/vpc"
}

# Locals are named constants that are reusable within the configuration.
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name              = "ref-arch-lite-${local.account_vars.locals.account_name}-rds"
  engine            = "mysql"
  engine_version    = "8.0.17"
  port              = 3306
  instance_type     = "db.t3.micro"
  allocated_storage = 5
  db_name           = "my_db"
  multi_az          = false
  master_username   = "admin"

  # To avoid storing the password in configuration, the master_password variable should be passed as an environment
  # variable. For example: export TF_VAR_master_password="<password>"

  # In staging, backups aren't critical, but we might want to keep them around for a little while
  backup_retention_period = 30

  # We deploy RDS into the App VPC, inside the private persistence tier.
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_persistence_subnet_ids

  # Here we allow any connection from the private app subnet tier of the VPC. You can further restrict network access by
  # security groups for better defense in depth.
  allow_connections_from_cidr_blocks     = dependency.vpc.outputs.private_app_subnet_cidr_blocks
  allow_connections_from_security_groups = []

  # TODO: Set up a "security logs and backups" account to store snapshots in
  share_snapshot_with_another_account = false

  # Only apply changes during the scheduled maintenance window, as certain DB changes cause degraded performance or
  # downtime. For more info, see:
  # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Modifying.html
  # Set this to true to immediately roll out the changes.
  apply_immediately = false
}
