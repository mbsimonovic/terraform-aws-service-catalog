# AWS App Account Baseline Example

This is an example of how to use the [account-baseline-app](/modules/landingzone/account-baseline-app) to establish security baseline
for AWS Landing Zone for configuring the app accounts (e.g., dev, stage, prod) of an AWS Organization - including setting up AWS Config, AWS CloudTrail,
Amazon Guard Duty, IAM users, IAM groups, IAM password policy, and more. This example is optimized for learning, experimenting, and testing (but not
direct production usage). If you want to deploy this module directly in production, check out the [examples/for-production folder](/examples/for-production).

## Quick start

To try these templates out you must have Terraform installed:

1. Open `variables.tf` and fill in any variables that don't have a default.
1. Run `terraform init` to instruct Terraform to perform initialization steps.
1. Run `terraform plan` to confirm that Terraform will create what looks like a reasonable set of resources.
1. Run `terraform apply`.
1. Now log into the AWS Web Console, and locate your new artifacts in IAM, Config, GuardDuty, etc.
