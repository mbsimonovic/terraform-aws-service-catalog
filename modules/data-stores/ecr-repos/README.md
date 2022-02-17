---
type: service
name: Amazon ECR Repositories
description: Create and manage multiple Amazon Elastic Container Repository (ECR) Repositories that can be used to store your Docker images.
category: docker-orchestration
cloud: aws
tags: ["data", "database", "container"]
license: gruntwork
built-with: terraform
---

# Amazon ECR Repositories

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

## Overview

This service contains code to create and manage multiple [Amazon Elastic Container Repository (ECR)](https://aws.amazon.com/ecr/)
Repositories that can be used for storing and distributing container images.

![ECR architecture](/_docs/ecr-architecture.png?raw=true)

## Features

- Create and manage multiple ECR repositories
- Store private Docker images for use in any Docker Orchestration system (e.g., Kubernetes, ECS, etc)
- Share repositories across accounts
- Fine grained access control
- Automatically scan Docker images for security vulnerabilities

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [ECR documentation](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html): Amazon’s docs for ECR
  that cover core concepts such as repository URLs, image scanning, and access control.

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
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

- [How to configure automatic image scanning](core-concepts.md#how-do-i-configure-automatic-image-scanning)
- [How to configure cross account repository access](core-concepts.md#how-do-i-configure-cross-account-repository-access)

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
