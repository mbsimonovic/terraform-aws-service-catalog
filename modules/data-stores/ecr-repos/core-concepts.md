# Core Concepts

## How do I configure automatic image scanning?

Amazon supports manually and automatically scanning Docker images that are pushed to ECR for security vulnerabilities. When you set the
`enable_automatic_image_scanning` property to `true`, the ECR repository will be configured to automatically scan all
images on every push.

You can learn more about what is involved in ECR image scanning in
[the official documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)

## How do I configure cross account repository access?

This module supports configuring IAM policies to allow another AWS account to:

- Pull and list images in the repository ("read access")
- Push new images or overwrite existing images ("write access")

To enable cross account access, provide the account IDs to grant the specified access to in the corresponding input
variables. You can set the accounts globally for all repositories once using
`var.default_external_account_ids_with_write_access` and `var.default_external_account_ids_with_read_access`, or for
each repository by setting the `external_account_ids_with_write_access` and `external_account_ids_with_read_access`
properties in `var.repositories`. When both are set, the module will prefer to use the one configured on the individual
repository.

Note that this only enables the permissions on the internal account to allow cross account ECR management. To allow IAM
users and roles in the external account to access, you will need to grant the same set of permissions in the external
account to the IAM users and roles. For convenience, this module outputs the policy actions that need to be allowed for
read or write access to the ECR repository in the outputs `ecr_read_policy_actions` and `ecr_write_policy_actions`.
