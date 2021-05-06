# Set account-wide variables
locals {
  account_name = "dev"
  domain_name = {
    name = "gruntwork-dev.com"
    properties = {
      created_outside_terraform = true
    }
  }
}
