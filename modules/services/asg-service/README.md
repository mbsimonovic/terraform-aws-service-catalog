---
type: service
name: Auto Scaling Group (ASG)
description: Deploy an AMI across an Auto Scaling Group (ASG), with support for zero-downtime, rolling deployment, load balancing, health checks, service discovery, and auto scaling.
category: services
cloud: aws
tags: ["asg", "ec2"]
license: gruntwork
built-with: terraform
---

# Auto Scaling Group

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue)

## Overview

This service contains code to deploy [Auto Scaling Groups](https://aws.amazon.com/ec2/autoscaling/) on AWS.

![ASG architecture](../../../_docs/asg-architecture.png?raw=true)

## Features

- Load balancer (ELB) integration
- Listener Rules
- Health checks
- Zero-downtime rolling deployment
- Route53 record

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-asg](https://github.com/gruntwork-io/terraform-aws-asg) repo. If you are a subscriber and don’t have
access to this repo, email <support@gruntwork.io>.

- [ASG Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/what-is-amazon-ec2-auto-scaling.html):
  Amazon’s docs for ASG that cover core concepts such as launch templates, launch configuration and auto scaling groups.
- [User Data](core-concepts.md)

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

- [What routes should I configure for each listener?](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/master/modules/lb-listener-rules#make-sure-your-listeners-handle-all-possible-request-paths)
- [How do I handle overlapping routes?](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/master/modules/lb-listener-rules#make-sure-your-listener-rules-each-have-a-unique-priority)

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
