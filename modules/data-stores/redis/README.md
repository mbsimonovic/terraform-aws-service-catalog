---
type: service
name: Amazon ElastiCache for Redis
description: Deploy and manage Amazon ElastiCache for Redis.
category: nosql
cloud: aws
tags: ["data", "database", "nosql", "redis", "elasticache"]
license: gruntwork
built-with: terraform
---

# Amazon ElastiCache for Redis

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

## Overview

This service contains code to deploy a Redis Cluster using Amazon ElastiCache. The cluster is managed by AWS and
automatically handles standby failover, read replicas, backups, patching, and encryption.

![ElastiCache for Redis architecture](/_docs/elasticache-redis-architecture.png?raw=true)

## Features

- Deploy a fully-managed Redis cluster
- Automatic failover to a standby in another availability zone
- Read replicas
- Automatic nightly snapshots
- Automatic cross account snapshots
- Automatic scaling of storage
- CloudWatch Alarms for alerting when CPU, memory, and disk metrics exceed certain thresholds
- Integrate with Kubernetes Service Discovery

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [What is Amazon ElastiCache?](https://github.com/gruntwork-io/terraform-aws-cache/tree/master/modules/redis#what-is-amazon-elasticache)
- [Common gotchas with ElastiCache](https://github.com/gruntwork-io/terraform-aws-cache/tree/master/modules/redis#common-gotchas)
- [Amazon ElastiCache for Redis documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/WhatIs.html):
  Amazon’s ElastiCache for Redis docs that cover core concepts such as the options and versions supported, security,
  backup & restore, and monitoring.
- *[Designing Data Intensive Applications](https://dataintensive.net)*: the best book we’ve found for understanding data
  systems, including relational databases, NoSQL, replication, sharding, consistency, and so on.

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

### Day-to-day operations

- [How to connect to a Redis cluster](https://github.com/gruntwork-io/terraform-aws-cache/tree/master/modules/redis#how-do-you-connect-to-the-redis-cluster)
- [Structure of an ElastiCache Redis deployment](https://github.com/gruntwork-io/terraform-aws-cache/tree/master/modules/redis#structure-of-an-elasticache-redis-deployment)
- [How to scale the Redis cluster](https://github.com/gruntwork-io/terraform-aws-cache/tree/master/modules/redis#how-do-you-scale-the-redis-cluster)
- [How do I use Kubernetes Service Discovery with the ElastiCache Redis Cluster?](core-concepts.md#how-do-i-use-kubernetes-service-discovery-with-the-elasticache-redis-cluster)

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
