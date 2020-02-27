# We should either source this directly from module-security... or move these account-baseline-xxx modules directly
# into this aws-service-catalog repo.
terraform {
  source = "git::git@github.com:gruntwork-io/module-security//modules/account-baseline-root?ref=v0.25.1"
}

inputs = {
  create_organization = true

  child_accounts = {
    acme-example-security = {
      email                      = "security-user@acme.com",
      iam_user_access_to_billing = "ALLOW",
      tags = {
        Account-Tag-Example = "tag-value"
      }
    },
    sandbox = {
      email = "sandbox@acme.com"
    }
  }
}