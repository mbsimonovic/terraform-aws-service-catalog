# IAM Users and IAM Groups Example

This is an example of how to use the [iam-users-and-groups](/modules/landingzone/iam-users-and-groups) module to manage
IAM Users and Groups for the security account of an AWS Organization. This example is optimized for learning,
experimenting, and testing (but not direct production usage). If you want to deploy this module directly in production,
check out the [examples/for-production folder](/examples/for-production).

## Quick start

To try these templates out you must have Terraform installed:

1. Open `variables.tf` and fill in any variables that don't have a default.
1. Run `terraform init` to instruct Terraform to perform initialization steps.
1. Run `terraform plan` to confirm that Terraform will create what looks like a reasonable set of resources.
1. Run `terraform apply`.
1. Now log into the AWS Web Console, and locate your new artifacts in IAM.
