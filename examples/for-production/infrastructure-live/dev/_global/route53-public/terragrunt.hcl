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
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/networking/route53?ref=v1.0.8"
  source = "../../../../../../modules//networking/route53"
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

  # Create a Route 53 public hosted zone and opt to provision a wildcard certificate protecting one subdomain level
  # e.g, if your dev_account_primary_domain_name is example.com and you set provision_wildcard_certificate to true, 
  # your resulting Amazon Certificate Manager (ACM) certificate will be issued for *.example.com and protect any 
  # subdomain at the top level, such as mail.example.com and www.example.com
  public_zones = {
    (local.dev_account_primary_domain_name) = {
      comment                        = "HostedZone created by Route53 Registrar"
      tags                           = {}
      force_destroy                  = false
      provision_wildcard_certificate = true
      created_outside_terraform      = true
      base_domain_name_tags = {
        original = true
      }
    }
  }
}
