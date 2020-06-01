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
  # TODO: Pin ref to the appropriate service catalog release
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/route53?ref=public-zone-lookup"
  #source = "../../../../../../modules/networking/route53"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Locals are named constants that are reusable within the configuration.
locals {
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  dev_account_primary_domain_name = local.common_vars.locals.domain_names.dev
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {

  ################################
  # Route53 inputs
  # These inputs are used to create Route53 .
  ################################

  public_zones = {
    "${local.dev_account_primary_domain_name}" = {
      comment                        = "HostedZone created by Route53 Registrar"
      tags                           = {}
      force_destroy                  = false
      provision_wildcard_certificate = true
      created_outside_terraform      = true
      base_domain_name_tags          = {}
    }
  }
}
