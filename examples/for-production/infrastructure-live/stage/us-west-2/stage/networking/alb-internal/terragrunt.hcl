
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
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/alb?ref=v0.60.1"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/networking/alb"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id                 = "vpc-abcd1234"
    vpc_cidr_block         = "10.0.0.0/16"
    private_app_subnet_ids = ["subnet-abcd1234", "subnet-bcd1234a", ]
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
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  alb_name = "grunt-sample-int-stage"

  # Since this is an internal ALB, we deploy it into the app VPC, inside the private tier.
  is_internal_alb = true
  vpc_id          = dependency.vpc.outputs.vpc_id
  vpc_subnet_ids  = dependency.vpc.outputs.private_app_subnet_ids

  # Since this is an internal ALB, we allow access from only the VPC range
  allow_inbound_from_cidr_blocks = [dependency.vpc.outputs.vpc_cidr_block]


  http_listener_ports = [80]
  https_listener_ports_and_acm_ssl_certs = [
    {
      port            = 443
      tls_domain_name = "${local.account_vars.locals.domain_name.name}"
    }
  ]

  create_route53_entry = true
  hosted_zone_id       = dependency.route53.outputs.public_hosted_zone_map[local.account_vars.locals.domain_name.name]
  domain_names         = ["gruntwork-sample-app-backend.${local.account_vars.locals.domain_name.name}"]

  num_days_after_which_archive_log_data = 7
  num_days_after_which_delete_log_data  = 30
  force_destroy                         = true
}