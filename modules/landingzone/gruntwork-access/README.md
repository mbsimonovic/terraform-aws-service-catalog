---
type: service
name: Gruntwork Access
description: Grant the Gruntwork team access to one of your AWS accounts so we can deploy a Reference Architecture for you or help with troubleshooting!
category: remote-access
cloud: aws
tags: ["reference-architecture", "troubleshooting"]
license: gruntwork
built-with: terraform
---

# Gruntwork Access

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

You can use this service to grant the Gruntwork team access to your AWS account to either:

- Deploying a [Reference Architecture](https://gruntwork.io/reference-architecture/)
- Helping your team with troubleshooting.

Under the hood, this service creates an [IAM Role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) in
your AWS account that the Gruntwork team can assume. This allows the Gruntwork team to securely access your AWS accounts
without having to create, share, or manage credentials.

## Features

- Create an IAM role that grants Gruntwork access to your AWS accounts
- Choose the Managed IAM Policy to grant
- Require MFA for assuming the IAM role
- Grant access to your own security account (required for Reference Architecture deployments)

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

- [What is the Gruntwork Reference Architecture?](https://gruntwork.io/reference-architecture/)

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
  `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and
  testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code
  optimized for direct usage in production. This is code from the
  [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog, configure CI / CD for your apps and
  infrastructure.

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
