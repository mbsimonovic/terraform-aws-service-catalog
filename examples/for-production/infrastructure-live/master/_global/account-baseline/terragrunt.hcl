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

  # This module deploys some resources (e.g., AWS Config) across all AWS regions, each of which needs its own provider,
  # which in Terraform means a separate process. To avoid all these processes thrashing the CPU, which leads to network
  # connectivity issues, we limit the parallelism here.
  extra_arguments "parallelism" {
    commands  = get_terraform_commands_that_need_parallelism()
    arguments = ["-parallelism=2"]
  }
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

locals {
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

  # Modules in the account _global folder don't live in any specific AWS region, but you still have to send the API
  # calls to _some_ AWS region, so here we pick an arbitrary region to use for those API calls.
  aws_region = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals.default_region

  # The default name of an IAM role that will be created in each child account. This role can be assumed from the root
  # account to  get admin access to the child accounts.
  organizations_default_role_name = "OrganizationAccountAccessRole"
}

# This generate block creates IAM roles in each of the child accounts that the Gruntwork team can use to get access to
# those child accounts and deploy the Reference Architecture.
#
# TODO: If the  Reference Architecture deployment is complete, you're deploying your own architecture based on this
# code, remove this generate block!!
generate "gruntwork_access" {
  path      = "gruntwork-access.tf"
  if_exists = "overwrite"
  contents  = templatefile("gruntwork-access.tmpl", {
    aws_region                      = local.aws_region
    child_accounts                  = local.child_accounts
    organizations_default_role_name = local.organizations_default_role_name
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # The child AWS accounts to create in this AWS organization and the IAM role to create in each account.
  child_accounts                  = local.child_accounts
  organizations_default_role_name = local.organizations_default_role_name

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
