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
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-root?ref=v1.0.8"
  source = "../../../../../../modules//landingzone/account-baseline-root"
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
