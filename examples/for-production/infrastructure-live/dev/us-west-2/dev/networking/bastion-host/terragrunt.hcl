# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/mgmt/bastion-host.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # We override the AMI filters just for the dev environment to show an example of how you can test a new version of the
  # Bastion host in a single environment. This setting replaces the `ami_filters` configuration defined in the base.
  ami_filters = {
    owners = [include.envcommon.locals.shared_account_id]
    filters = [
      {
        name   = "name"
        values = ["bastion-host-v0.65.0-*"]
      },
    ]
  }

  instance_type = "t3.micro"
}