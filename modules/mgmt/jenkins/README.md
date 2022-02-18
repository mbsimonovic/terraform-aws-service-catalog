---
type: service
name: Jenkins
description: Deploy Jenkins CI Server on AWS.
category: ci-cd
cloud: aws
tags: ["jenkins", "ec2", "ci", "cd", "ci-cd"]
license: gruntwork
built-with: terraform, bash, packer
---

# Jenkins CI Server

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

## Overview

This service contains code to deploy [Jenkins CI Server](https://jenkins.io/) on AWS.

![Jenkins architecture](../../../_docs/jenkins-architecture.png?raw=true)

## Features

- Deploy Jenkins CI Server
- Run Jenkins in an Auto Scaling Group for high availability
- Store the `JENKINS_HOME` directory in an EBS Volume
- Take nightly snapshots of the EBS Volume using the `ec2-backup` scheduled Lambda function
- Run an ALB in front of Jenkins so it’s not accessible directly to users
- Configure DNS in Route 53 and TLS in AWS Certificate Manager (ACM)
- Send all logs and metrics to CloudWatch
- Configure alerts in CloudWatch for CPU, memory, and disk space usage
- Manage SSH access with IAM groups using `ssh-grunt`
- Manage deployment permissions for the server using IAM roles
- OS hardening, including `fail2ban`, `ntp`, `auto-update`, `ip-lockdown`, and more

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [CI/ CD Core Concepts](https://docs.gruntwork.io/guides/build-it-yourself/pipelines/core-concepts/why-is-it-important-to-have-ci-cds):
  An overview of the core concepts you need to understand what a typical CI/CD pipeline entails for application and
  infrastructure code, including a sample workflow, infrastructure to support CI/CD, an threat models to consider to
  protect your infrastructure.

- [Jenkins Documentation](https://jenkins.io/doc/): The official documentation for Jenkins.

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
  [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

- [How to configure a production-grade CI/CD workflow for application and infrastructure code](https://docs.gruntwork.io/guides/build-it-yourself/pipelines/):
  step-by-step guide on how to configure CI / CD for your apps and infrastructure.

## Operate

### Day-to-day operations

- [The JENKINS\_HOME directory](core-concepts.md#the-jenkins_home-directory)
- [Why use an ALB?](core-concepts.md#why-use-an-alb)

### Major changes

- [Upgrading Jenkins](core-concepts.md#upgrading-jenkins)

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
