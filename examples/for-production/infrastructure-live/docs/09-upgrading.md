# Upgrading your Reference Architecture

* [Upgrading Terraform](#upgrading-terraform): How to upgrade terraform easily across your modules.

## Upgrading Terraform

The CI / CD pipeline's workhorse, the ECS Deploy Runner, includes a terraform version manager,
[`tfenv`](https://github.com/tfutils/tfenv), so that you can run multiple versions of Terraform with your
`infrastructure-live` repo. This is especially useful when you want to upgrade Terraform versions.

1. You'll first need to add a `.terraform-version` file to the module directory of the module you're upgrading.
1. In that file, specify the terraform version as a string, e.g. `1.0.8`. Then push your changes to a branch.
1. The CI / CD pipeline will detect the change to the module and run `plan` on that module. When it does this, it will
use the specified terraform version.
1. After the changes are merged to your default protected branch, and after approval, the changes will be `apply`ed
using the specified terraform version.
1. The `.tfstate` state file will be written in that version. You can verify this by viewing the state file in the S3
bucket containing all your Reference Architecture's state files.

You can read more about how this works in the main
[ECS Deploy Runner docs](https://github.com/gruntwork-io/terraform-aws-ci/blob/ee2d941946824bdabbac6830dc6cf66f9ee69bec/modules/ecs-deploy-runner/core-concepts.md#how-do-i-use-the-deploy-runner-with-multiple-terraform-versions).
