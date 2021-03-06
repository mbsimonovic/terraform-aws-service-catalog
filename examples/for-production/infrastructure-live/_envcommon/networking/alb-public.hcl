# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for networking/alb-public. The common variables for each environment to
# deploy networking/alb-public are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/alb?ref=v0.82.0"
  source = "${get_parent_terragrunt_dir()}/../../../../..//modules/networking/alb"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id            = "vpc-abcd1234"
    public_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "route53" {
  config_path = "${get_terragrunt_dir()}/../../../../_global/route53-public"

  mock_outputs = {
    public_hosted_zone_map = {
      ("${local.account_vars.locals.domain_name.name}") = "some-zone"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/alb"

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
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above.
# This defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Since this is an external public facing ALB, we deploy it into the app VPC, inside the public tier.
  is_internal_alb = false
  vpc_id          = dependency.vpc.outputs.vpc_id
  vpc_subnet_ids  = dependency.vpc.outputs.public_subnet_ids

  # Since this is a public-facing ALB, we allow access from the entire Internet
  allow_inbound_from_cidr_blocks = ["0.0.0.0/0"]

  http_listener_ports = [80]
  https_listener_ports_and_acm_ssl_certs = [
    {
      port            = 443
      tls_domain_name = "${local.account_vars.locals.domain_name.name}"
    }
  ]

  create_route53_entry = true
  hosted_zone_id       = dependency.route53.outputs.public_hosted_zone_map[local.account_vars.locals.domain_name.name]
  domain_names         = ["gruntwork-sample-app.${local.account_vars.locals.domain_name.name}"]

  num_days_after_which_archive_log_data = 7
  num_days_after_which_delete_log_data  = 30
  force_destroy                         = true
}