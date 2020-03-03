# AWS Root Account Baseline Example

This is an example of how to use the [account-baseline-root](/modules/landingzone/account-baseline-root) to establish security baseline
for AWS Landing Zone for configuring the root account (AKA master account) of an AWS Organization - including setting up child accounts,
AWS Config, AWS CloudTrail, Amazon Guard Duty, IAM users, IAM groups, IAM password policy, and more. This example is optimized for
learning, experimenting, and testing (but not direct production usage). If you want to deploy this module directly in production, check
out the [examples/for-production folder](/examples/for-production).

**NOTE:** Destroying the example via `terraform destroy` or removing entries from `child_accounts` will only remove an AWS account from an organization.
Terraform **will not close the account**. The member account must be prepared to be a standalone account beforehand.
See the [AWS Organizations documentation](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_remove.html)
for more information.

## Quick start

To try these templates out you must have Terraform installed:

1. Open `variables.tf` and fill in any variables that don't have a default.
1. Run `terraform init` to instruct Terraform to perform initialization steps.
1. Run `terraform plan` to confirm that Terraform will create what looks like a reasonable set of resources.
1. Run `terraform apply`.
1. Now log into the AWS Web Console, go to the Organizations console, and locate your new child accounts.
