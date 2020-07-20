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
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/data-stores/elasticsearch?ref=v1.2.3"
  source = "../../../../../../../../modules//data-stores/elasticsearch"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# We set prevent destroy here to prevent accidentally deleting your company's data in case of overly ambitious use
# of destroy or destroy-all. If you really want to run destroy on this module, remove this flag.
prevent_destroy = true

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {

  domain_name            = "aes-cluster"
  instance_type          = "t2.small.elasticsearch"
  instance_count         = 2
  volume_type            = "standard"
  volume_size            = 10
  zone_awareness_enabled = true
  vpc_id                 = "vpc-0e0d9a6b"
  subnet_ids             = ["subnet-1cb53110", "subnet-0cd80b55", "subnet-d377c6a4"]
}
