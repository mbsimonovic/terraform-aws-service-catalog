---
type: service
name: Amazon ECS Cluster
description: Deploy an Amazon ECS Cluster.
category: docker-orchestration
cloud: aws
tags: ["docker", "orchestration", "ecs", "containers"]
license: gruntwork
built-with: terraform, bash, python, go
---

# Amazon ECS Cluster

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service contains [Terraform](https://www.terraform.io) code to deploy a production-grade ECS cluster on
[AWS](https://aws.amazon.com) using [Elastic Container Service (ECS)](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html).

This service launches an ECS cluster on top of an Auto Scaling Group that you manage. If you wish to launch an ECS
cluster on top of Fargate that is completely managed by AWS, refer to the
[ecs-fargate-cluster module](../ecs-fargate-cluster). Refer to the section
[EC2 vs Fargate Launch Types](https://github.com/gruntwork-io/terraform-aws-ecs/blob/master/core-concepts.md#ec2-vs-fargate-launch-types)
for more information on the differences between the two flavors.

![ECS architecture](/_docs/ecs-architecture.png?raw=true)

## Features

This Terraform Module launches an [EC2 Container Service Cluster](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_clusters.html) that you can use to run Docker containers. The cluster consists of a configurable number of instances in an Auto Scaling
Group (ASG). Each instance:

- Runs the [ECS Container Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) so it can communicate with the ECS scheduler.

- Authenticates with a Docker repo so it can download private images. The Docker repo auth details should be encrypted
  using [Amazon Key Management Service (KMS)](https://aws.amazon.com/kms/) and passed in as input variables. The
  instances, when booting up, will use [gruntkms](https://github.com/gruntwork-io/gruntkms) to decrypt the data
  in-memory. Note that the IAM role for these instances, which uses `var.cluster_name` as its name, must be granted
  access to the
  [Customer Master Key (CMK)](http://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys)
  used to encrypt the data.

- Runs the
  [CloudWatch Logs Agent](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/QuickStartEC2Instance.html)
  to send all logs in syslog to
  [CloudWatch Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/WhatIsCloudWatchLogs.html). This
  is configured using the
  [cloudwatch-agent](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent).

- Emits custom metrics that are not available by default in CloudWatch, including memory and disk usage. This is
  configured using the [cloudwatch-agent
  module](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent).

- Runs the [syslog module](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/syslog)
  to automatically rotate and rate limit syslog so that your instances don’t run out of disk space from large volumes.

- Runs the [ssh-grunt module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt) so
  that developers can upload their public SSH keys to IAM and use those SSH keys, along with their IAM user names, to
  SSH to the ECS Nodes.

- Runs the [auto-update module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/auto-update)
  so that the ECS nodes install security updates automatically.

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

To understand core concepts like what is ECS, and the different cluster types, see the documentation in the
[terraform-aws-ecs](https://github.com/gruntwork-io/terraform-aws-ecs) repo.

To use ECS, you first deploy one or more EC2 Instances into a "cluster". The ECS scheduler can then deploy Docker
containers across any of the instances in this cluster. Each instance needs to have the
[Amazon ECS Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) installed so it can
communicate with ECS and register itself as part of the right cluster.

For more info on ECS clusters, including how to run Docker containers in a cluster, how to add additional security
group rules, how to handle IAM policies, and more, check out the
[ecs-cluster documentation](https://github.com/gruntwork-io/terraform-aws-ecs/tree/master/modules/ecs-cluster) in the
[terraform-aws-ecs repo](https://github.com/gruntwork-io/terraform-aws-ecs).

For info on finding your Docker container logs and custom metrics in CloudWatch, check out the
[cloudwatch-agent documentation](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/agents/cloudwatch-agent).

### Repo organization

- [modules](/modules): the main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.
- [examples](/examples): This folder contains working examples of how to use the submodules.
- [test](/test): Automated tests for the modules and examples.

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

## Manage

For information on how to configure cluster autoscaling, see
[How do you configure cluster autoscaling?](https://github.com/gruntwork-io/terraform-aws-ecs/tree/master/modules/ecs-cluster#how-do-you-configure-cluster-autoscaling)

For information on how to manage your ECS cluster, see the documentation in the
[terraform-aws-ecs](https://github.com/gruntwork-io/terraform-aws-ecs) repo.

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
