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
    private_persistence_subnet_ids = ["mock-subnet-1cb", "mock-subnet-0cd", "mock-subnet-d37"]
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

# We set prevent destroy here to prevent accidentally deleting your company's data in case of overly ambitious use
# of destroy or destroy-all. If you really want to run destroy on this module, remove this flag.
prevent_destroy = true

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

# NOTE: You'll need to add a Service-Linked Role for Elasticsearch
# (https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/slr-es.html) within your AWS account.
# The role is named `es.amazonaws.com`. You can create and manage it via the AWS Console UI.

inputs = {
  domain_name            = "aws-es-cluster"
  instance_type          = "t2.small.elasticsearch"
  instance_count         = 2
  volume_type            = "standard"
  volume_size            = 10
  zone_awareness_enabled = true

  # We deploy Elasticsearch into the App VPC, inside the private persistence tier.
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_persistence_subnet_ids
}
