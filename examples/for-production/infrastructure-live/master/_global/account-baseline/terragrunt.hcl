# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that supports locking and enforces best
# practices: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder.
terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-root?ref=landing-zone-v1"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # The child AWS accounts to create in this AWS organization
  child_accounts = {
    security = {
      email = "root-accounts+security@acme.com",
    },
    shared-services = {
      email = "root-accounts+shared-services@acme.com"
    },
    dev = {
      email = "root-accounts+dev@acme.com"
    },
    stage = {
      email = "root-accounts+stage@acme.com"
    },
    prod = {
      email = "root-accounts+prod@acme.com"
    }
  }

  # The IAM users to create in this account. Since this is the root account, we should only create IAM users for a
  # small handful of trusted admins.
  users = {
    alice = {
      groups               = ["full-access"]
      pgp_key              = "keybase:alice_on_keybase"
      create_login_profile = true
      create_access_keys   = false
    }
  }
}
