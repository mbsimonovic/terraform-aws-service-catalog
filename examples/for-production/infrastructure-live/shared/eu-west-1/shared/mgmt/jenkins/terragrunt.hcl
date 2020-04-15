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
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/jenkins?ref=master"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# When using the terragrunt xxx-all commands (e.g., apply-all, plan-all), deploy these dependencies before this module
dependencies {
  paths = ["../../../../_global/account-baseline"]
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
  name          = "ref-arch-lite-${local.account_vars.locals.account_name}-jenkins"
  ami           = "ami-abcd1234"
  instance_type = "t3.micro"
  memory        = "512m"

  vpc_id            = dependency.vpc.outputs.vpc_id
  jenkins_subnet_id = dependency.vpc.outputs.private_app_subnet_ids[0]
  alb_subnet_ids    = dependency.vpc.outputs.public_subnet_ids

  keypair_name               = "jim-brikman"
  allow_ssh_from_cidr_blocks = ["0.0.0.0/0"]
  enable_ssh_grunt           = false

  is_internal_alb                      = false
  allow_incoming_http_from_cidr_blocks = ["0.0.0.0/0"]

  # TODO: We'd normally use a dependency block to pull in the hosted zone ID, but we haven't converted the route 53
  # modules to the new service catalog format yet, so for now, we just hard-code the ID.
  hosted_zone_id             = "Z2AJ7S3R6G9UYJ"
  domain_name                = "ref-arch-lite-${local.account_vars.locals.account_name}-jenkins.gruntwork.in"
  acm_ssl_certificate_domain = "*.gruntwork.in"
}
