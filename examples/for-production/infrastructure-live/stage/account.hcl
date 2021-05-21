# Set account-wide variables
locals {
  account_name = "stage"
  domain_name = {
    name = "gruntwork-stage.com"
    properties = {
      created_outside_terraform = true
    }
  }
}
