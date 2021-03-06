---
type: service
name: AWS Root Account baseline wrapper
description: A security baseline for AWS Landing Zone for configuring the root account (AKA master account) of an AWS Organization, including setting up child accounts, AWS Config, AWS CloudTrail, Amazon Guard Duty, IAM users, IAM groups, IAM password policy, and more.
category: landing-zone
cloud: aws
tags: ["aws-landing-zone", "logging", "security"]
license: gruntwork
built-with: terraform
---

# Account Baseline for root account

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

A security baseline for AWS Landing Zone for configuring the root account (AKA master account) of an AWS Organization, including setting up
child accounts, AWS Config, AWS CloudTrail, Amazon Guard Duty, IAM users, IAM groups, IAM password policy, and more.

## Features

Get a secure baseline for the root account of your AWS Organization that includes:

- [aws-config-multi-region](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/aws-config-multi-region)
- [aws-organizations](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/aws-organizations)
- [aws-organizations-config-rules](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/aws-organizations-config-rules)
- [cloudtrail](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/cloudtrail)
- [cross-account-iam-roles](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/cross-account-iam-roles)
- [guardduty-multi-region](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/guardduty-multi-region)
- [iam-groups](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/iam-groups)
- [iam-users](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/iam-users)
- [iam-user-password-policy](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/iam-user-password-policy)

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you???ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

- Learn more about each individual module, click the link in the [Features](#features) section
- [How to configure a production-grade AWS account structure](https://docs.gruntwork.io/guides/build-it-yourself/landing-zone/)
- [How to create child accounts](/core-concepts.md#creating-child-accounts)
- [How to aggregate AWS Config and CloudTrail data in a logs account](/core-concepts.md#aggregating-aws-config-and-cloudtrail-data-in-a-logs-account)
- [Why does this module use account-level AWS Config Rules?](/core-concepts.md#why-does-this-module-use-account-level-aws-config-rules)
- [How to use multi-region services](/core-concepts.md#how-to-use-multi-region-services)

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
  end-to-end integrated tech stack on top of the Gruntwork Service Catalog.

- [How to configure a production-grade AWS account structure](https://docs.gruntwork.io/guides/build-it-yourself/landing-zone/)

## Support

If you need help with this repo, [post a question in our knowledge base](https://github.com/gruntwork-io/knowledge-base/discussions?discussions_q=label%3Ar%3Aterraform-aws-service-catalog)
or [reach out via our support channels](https://docs.gruntwork.io/support) included with your subscription. If you???re
not yet a Gruntwork subscriber, [subscribe now](https://www.gruntwork.io/pricing/).

## Contributions

Contributions to this repo are both welcome and appreciated! If you fix a bug, add a new feature, or even wish to
contribute an entirely new module, we???re happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.
See our [contribution guide](https://docs.gruntwork.io/guides/working-with-code/contributing) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
