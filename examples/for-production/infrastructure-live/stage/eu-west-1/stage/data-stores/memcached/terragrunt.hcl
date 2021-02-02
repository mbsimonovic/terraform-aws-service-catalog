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
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/memcached?ref=v1.0.8"
  source = "../../../../../../../../modules//data-stores/memcached"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Pull in outputs from these modules to compute inputs. These modules will also be added to the dependency list for
# xxx-all commands.
# For each dependency, we also set mock outputs that can be used for running `validate-all` without having to apply the
# underlying modules. Note that we only use this path for validation of the module, as using mock values for `plan-all`
# can lead to unintended consequences.
dependency "vpc" {
  config_path = "../../networking/vpc"

  mock_outputs = {
    vpc_id                         = "mock-vpc-id"
    private_app_subnet_cidr_blocks = ["1.2.3.4/24"]
    private_persistence_subnet_ids = ["mock-subnet-id-priv-persist"]
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
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
  name              = "ref-arch-lite-${local.account_vars.locals.account_name}-memcached"
  memcached_version = "1.5.16"
  port              = 11211
  instance_type     = "cache.t3.micro"

  num_cache_nodes = 1
  az_mode         = "single-az"

  # We deploy RDS into the App VPC, inside the private persistence tier.
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_persistence_subnet_ids

  # Here we allow any connection from the private app subnet tier of the VPC. You can further restrict network access by
  # security groups for better defense in depth.
  allow_connections_from_cidr_blocks     = dependency.vpc.outputs.private_app_subnet_cidr_blocks
  allow_connections_from_security_groups = []

  # Only apply changes during the scheduled maintenance window, as certain DB changes cause degraded performance or
  # downtime. For more info, see: https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/Clusters.Modify.html
  # We set this to true to immediately roll out the changes in non-prod environments.
  apply_immediately = true
}
