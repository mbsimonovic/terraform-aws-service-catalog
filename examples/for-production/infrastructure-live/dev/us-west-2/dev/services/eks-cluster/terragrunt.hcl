# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/services/eks-cluster.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {

  # We override the AMI filters just for the dev environment to show an example of how you can test a new version of the
  # EKS Cluster AMI in a single environment. This setting replaces the `ami_filters` configuration defined in the base.
  cluster_instance_ami_filters = {
    owners = [include.envcommon.locals.common_vars.locals.account_ids.shared]
    filters = [
      {
        name   = "name"
        values = ["eks-workers-v0.70.0-*"]
      },
    ]
  }
}