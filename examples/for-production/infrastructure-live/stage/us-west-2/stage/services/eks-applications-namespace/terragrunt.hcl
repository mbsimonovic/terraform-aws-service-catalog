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
  source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/k8s-namespace?ref=v0.34.1"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

dependency "eks_cluster" {
  config_path = "${get_terragrunt_dir()}/../eks-cluster"

  mock_outputs = {
    eks_cluster_name = "${local.name_prefix}-${local.account_name}"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}



# Generate a Kubernetes provider configuration for authenticating against the EKS cluster.
generate "k8s_helm" {
  path      = "k8s_helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile(
    find_in_parent_folders("provider_k8s_helm_for_eks.template.hcl"),
    { eks_cluster_name = dependency.eks_cluster.outputs.eks_cluster_name },
  )
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

  # Extract the account_name for easy access
  account_name = local.account_vars.locals.account_name

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
  name = "applications"
}