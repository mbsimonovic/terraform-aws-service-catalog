# Gruntwork Account Access Example

This is an example of how to use the [gruntwork-access](/modules/landingzone/gruntwork-access) module to grant the
Gruntwork team access to your AWS account to (a) deploy a Reference Architecture or (b) help with troubleshooting.

This example is optimized for learning, experimenting, and testing (but not direct production usage). If you want to 
deploy this module directly in production, check out the [examples/for-production folder](/examples/for-production).

## Quick start

To try these templates out you must have Terraform installed:

1. Open `variables.tf` and fill in any variables that don't have a default.
1. Run `terraform init` to instruct Terraform to perform initialization steps.
1. Run `terraform plan` to confirm that Terraform will create what looks like a reasonable set of resources.
1. Run `terraform apply`.
