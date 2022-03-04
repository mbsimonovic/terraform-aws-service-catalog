---
type: service
name: Amazon ECS Service
description: Deploy an Amazon ECS Service.
category: docker-orchestration
cloud: aws
tags: ["docker", "orchestration", "ecs", "containers"]
license: gruntwork
built-with: terraform, bash, python, go
---

# Amazon ECS Service

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service contains [Terraform](https://www.terraform.io) code to deploy a production-grade ECS service on
[AWS](https://aws.amazon.com) using [Elastic Container Service(ECS)](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html).

![ECS architecture](/_docs/ecs-architecture.png?raw=true)

## Features

- Deploy an ECS Service onto an existing ECS cluster
- Define arbitrary tasks via JSON
- Optionally deploy a canary task for testing release candidates
- Configure and deploy load balancing and optional DNS records
- Auto scaling of ECS tasks
- Cloudwatch metrics and alerts

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-ecs](https://github.com/gruntwork-io/terraform-aws-ecs) repo. If you are a subscriber and don’t have
access to this repo, email <support@gruntwork.io>.

### Core concepts

To understand core concepts like what is ECS, the different cluster types, how to authenticate to Kubernetes, and
more, see the documentation in the
[terraform-aws-ecs](https://github.com/gruntwork-io/terraform-aws-ecs) repo.

### Repo organization

- [modules](/modules): the main implementation code for this repo, broken down into multiple standalone, orthogonal
  submodules.
- [examples](/examples): This folder contains working examples of how to use the submodules.
- [test](/test): Automated tests for the modules and examples.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
`examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code
  optimized for direct usage in production. This is code from the
  [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Manage

For information on how to manage your ECS service, see the documentation in the
[module ecs](https://github.com/gruntwork-io/terraform-aws-ecs) repo.

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
