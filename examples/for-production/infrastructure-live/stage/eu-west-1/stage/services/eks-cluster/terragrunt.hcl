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
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/eks-cluster?ref=master"
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

# We set prevent destroy here to prevent accidentally deleting your company's data in case of overly ambitious use
# of destroy or destroy-all. If you really want to run destroy on this module, remove this flag.
prevent_destroy = true

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
  cluster_name          = "ref-arch-lite-${local.account_vars.locals.account_name}"
  cluster_instance_ami  = "ami-abcd1234"
  cluster_instance_type = "t3.small"

  # We deploy EKS into the App VPC, inside the private app tier.
  vpc_id                       = dependency.vpc.outputs.vpc_id
  control_plane_vpc_subnet_ids = dependency.vpc.outputs.private_app_subnet_ids

  # Due to localization limitations for EKS, it is recommended to have separate ASGs per availability zones. Here we
  # deploy one ASG per subnet.
  autoscaling_group_configurations = {
    for subnet_id in dependency.vpc.outputs.private_app_subnet_ids :
    subnet_id => {
      min_size   = 1
      max_size   = 2
      subnet_ids = [subnet_id]
      tags       = []
    }
  }

  # Here we restrict Kubernetes API connections to only those originating from within the VPC, and specifically the
  # private app subnet CIDR blocks.
  endpoint_public_access                    = false
  allow_inbound_api_access_from_cidr_blocks = dependency.vpc.outputs.private_app_subnet_cidr_blocks
}
