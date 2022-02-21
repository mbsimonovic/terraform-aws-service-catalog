---
type: service
name: IAM Users and IAM Groups
description: Convenient service for managing best practices set of IAM Groups for permissions management, and configuring IAM Users that take advantage of those groups.
category: landing-zone
cloud: aws
tags: ["aws-landing-zone", "logging", "security"]
license: gruntwork
built-with: terraform
---

# IAM Users and IAM Groups

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service contains [Terraform](https://www.terraform.io) code to provision and manage best practices set of IAM
Groups for permissions management, and configuring IAM Users that take advantage of those groups.

This feature exists in `account-baseline-security`, but having a separate module to manage IAM Users and Groups is
useful for large scale organizations that frequently:

- Onboard and offboard new users
- Add and remove AWS accounts in their org

The rationale behind this change comes from addressing two issues:

- The cadence of changes for IAM users and groups in the security account is considerably higher than the other things
  that are managed in `account-baseline-security` (e.g., consider CloudTrail, which should only be configured once in
  the lifetime of the account).

- `account-baseline-security` is, by nature, a heavy module that manages tons of resources. Having to go through the
  `plan` and `apply` cycle for all those resources can be very painful, especially for large orgs that need to
  onboard/offboard user frequently.

## Features

- Provision IAM users with default set of IAM Groups, passwords, and access keys.

- Manage a best practices set of IAM Groups for managing different permissions levels in your AWS Account.

- Provision IAM Groups that manage cross account IAM Role access to other accounts in your AWS Organization.

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

- [iam-users module documentation](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/iam-users): Underlying
  module used to manage the IAM Users from this module.
- [iam-groups module documentation](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/iam-groups): Underlying
  module used to manage the IAM Groups from this module.
- [How to configure a production-grade AWS account structure](https://docs.gruntwork.io/guides/build-it-yourself/landing-zone/)

### Repo organization

- [modules](/modules): the main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.
- [examples](/examples): This folder contains working examples of how to use the submodules.
- [test](/test): Automated tests for the modules and examples.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing/landingzone folder](/examples/for-learning-and-testing/landingzone): The
  `examples/for-learning-and-testing/landingzone` folder contains standalone sample code optimized for learning,
  experimenting, and testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code
  optimized for direct usage in production. This is code from the
  [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

- [How to configure a production-grade AWS account structure](https://docs.gruntwork.io/guides/build-it-yourself/landing-zone/)

## Support

If you need help with this repo, [post a question in our knowledge base](https://github.com/gruntwork-io/knowledge-base/discussions?discussions_q=label%3Ar%3Aterraform-aws-service-catalog)
or [reach out via our support channels](https://docs.gruntwork.io/support) included with your subscription. If you’re
not yet a Gruntwork subscriber, [subscribe now](https://www.gruntwork.io/pricing/).

## Contributions

Contributions to this repo are both welcome and appreciated! If you fix a bug, add a new feature, or even wish to
contribute an entirely new module, we’re happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.
See our [contribution guide](https://docs.gruntwork.io/guides/working-with-code/contributing) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
