# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/landingzone/account-baseline-app-base.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# Include the envcommon configuration for the app accounts. This envcommon contains settings for the
# account-baseline-app module that is common across app accounts (e.g., dev, stage, prod), as opposed to supplemental
# accounts like shared and logs.
include "appcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/landingzone/account-baseline-app-appaccount.hcl"
  # Perform a deep merge so that we can reference dependencies in the override parameters.
  merge_strategy = "deep"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {}