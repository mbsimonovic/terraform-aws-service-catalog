terraform {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/landingzone/account-baseline-root?ref=v0.0.1"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  # Prefix all resources with this name
  name_prefix = "ref-arch-lite"

  # The child AWS accounts to create in this AWS organization
  child_accounts = {
    security = {
      email = "root-acconts+security@acme.com",
    },
    shared-services = {
      email = "root-acconts+shared-services@acme.com"
    },
    dev = {
      email = "root-acconts+dev@acme.com"
    },
    stage = {
      email = "root-acconts+stage@acme.com"
    },
    prod = {
      email = "root-acconts+prod@acme.com"
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