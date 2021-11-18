# Set account-wide variables
locals {
  account_name = "shared"
  account_role = "shared"
  domain_name = {
    name = "gruntwork-shared.com"
    properties = {
      created_outside_terraform = true
    }
  }
}
