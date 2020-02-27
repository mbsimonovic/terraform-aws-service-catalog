# We should either source this directly from module-security... or move these account-baseline-xxx modules directly
# into this aws-service-catalog repo.
terraform {
  source = "git::git@github.com:gruntwork-io/module-security//modules/account-baseline-security?ref=v0.25.1"
}

inputs = {
  user = {
    alice = {
      groups = ["user-self-mgmt", "developers", "ssh-sudo-users"]
    }

    bob = {
      path   = "/"
      groups = ["user-self-mgmt", "ops", "admins"]
      tags   = {
        foo = "bar"
      }
    }

    carol = {
      groups               = ["user-self-mgmt", "developers", "ssh-users"]
      pgp_key              = "keybase:carol_on_keybase"
      create_login_profile = true
      create_access_keys   = true
    }
  }
}