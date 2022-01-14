# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for data-stores/rds. The common variables for each environment to
# deploy data-stores/rds are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/rds?ref=v0.70.0"
  source = "${get_parent_terragrunt_dir()}/../../../../..//modules/data-stores/rds"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id                         = "vpc-abcd1234"
    private_persistence_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
    private_app_subnet_cidr_blocks = ["10.0.0.0/24", "10.0.1.0/24", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "network_bastion" {
  config_path = "${get_terragrunt_dir()}/../../networking/openvpn-server"

  mock_outputs = {
    security_group_id = "sg-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "sns" {
  config_path = "${get_terragrunt_dir()}/../../../_regional/sns-topic"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:123456789012:mytopic-NZJ5JSMVGFIE"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/rds"

  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name and account_role for easy access
  account_name = local.account_vars.locals.account_name
  account_role = local.account_vars.locals.account_role

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

  account_id = local.common_vars.locals.account_ids[local.account_name]
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above.
# This defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name              = "rds-${local.name_prefix}-${local.account_name}"
  engine_version    = "8.0"
  instance_type     = "db.t3.micro"
  allocated_storage = "20"

  # Configure the logs that should be shipped to CloudWatch
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  # Enable deletion protection
  enable_deletion_protection = true

  # Specifies whether to deploy a standby instance to another availability zone. RDS will automatically failover
  # to the standby in the event of a problem with the primary.
  multi_az = false

  # We deploy RDS inside the private persistence tier.
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_persistence_subnet_ids

  # Here we allow any connection from the private app subnet tier of the VPC. You can further restrict network access by
  # security groups for better defense in depth.
  allow_connections_from_cidr_blocks = dependency.vpc.outputs.private_app_subnet_cidr_blocks
  # We also allow access from the network bastion.
  allow_connections_from_security_groups = [dependency.network_bastion.outputs.security_group_id]

  # The RDS service module will create a KMS CMK. With these settings, we allow the key access to be managed via IAM.
  # To understand how this works, see: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html
  cmk_administrator_iam_arns = [
    "arn:aws:iam::${local.account_id}:root",
  ]
  cmk_user_iam_arns = [
    {
      name       = ["arn:aws:iam::${local.account_id}:root"],
      conditions = [],
    },
  ]

  # Send CloudWatch alarms to SNS. To receive alarms you must subscribe to this topic separately.
  alarms_sns_topic_arns = [dependency.sns.outputs.topic_arn]

  # Only apply changes during the scheduled maintenance window, as certain DB changes cause degraded performance or
  # downtime. For more info, see:
  # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Modifying.html
  # Set this to true to immediately roll out the changes.
  apply_immediately = false

  # Deletion protection is a precaution to avoid accidental data loss by protecting the instance from being deleted.
  enable_deletion_protection = false
}