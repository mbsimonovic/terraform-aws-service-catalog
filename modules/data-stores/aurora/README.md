---
type: service
name: Amazon Aurora
description: Deploy and manage Amazon Aurora using Amazon's Relational Database Service (RDS).
category: database
cloud: aws
tags: ["data", "database", "sql", "rds", "aurora"]
license: gruntwork
built-with: terraform
---

# Amazon Aurora

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service contains code to deploy an Amazon Relational Database Service (RDS) cluster that can run
[Amazon Aurora](https://aws.amazon.com/rds/aurora/), Amazon’s cloud-native relational database. The cluster is managed
by AWS and automatically handles standby failover, read replicas, backups, patching, and encryption.

![RDS architecture](/_docs/rds-architecture.png?raw=true)

## Features

- Deploy a fully-managed, cloud-native relational database
- MySQL and PostgreSQL compatibility
- Automatic failover to a standby in another availability zone
- Read replicas
- Automatic nightly snapshots
- Automatic cross account snapshots
- Automatic scaling of storage
- Scale to 0 with Aurora Serverless
- Integrate with Kubernetes Service Discovery

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [What is Amazon RDS?](https://github.com/gruntwork-io/terraform-aws-data-storage/blob/master/modules/aurora/core-concepts.md#what-is-amazon-rds)
- [Common gotchas with RDS](https://github.com/gruntwork-io/terraform-aws-data-storage/blob/master/modules/aurora/core-concepts.md#common-gotchas)
- [Aurora Serverless documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless.html):
  Amazon’s docs for Aurora Serverless, including its advantages, limitations, architecture, and scaling configurations.
- [RDS documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html): Amazon’s docs for RDS that
  cover core concepts such a the types of databases supported, security, backup & restore, and monitoring.
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
  optimized for direct usage in production. This is code from the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/),
  and it shows you how we build an end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

### Day-to-day operations

- [How to deploy Aurora Serverless](core-concepts.md#how-do-i-deploy-aurora-serverless)
- [How to connect to an Aurora instance](https://github.com/gruntwork-io/terraform-aws-data-storage/blob/master/modules/aurora/core-concepts.md#how-do-you-connect-to-the-database)
- [How to authenticate to RDS with IAM](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAM.html)
- [How to scale Aurora](https://github.com/gruntwork-io/terraform-aws-data-storage/blob/master/modules/aurora/core-concepts.md#how-do-you-scale-this-database)
- [How to scale Aurora Serverless](core-concepts.md#how-do-i-scale-the-aurora-serverless-database)
- [How to backup Aurora snapshots to a separate AWS account](core-concepts.md#how-do-you-backup-your-rds-snapshots-to-a-separate-aws-account)
- [How do I use Kubernetes Service Discovery with the Aurora database?](core-concepts.md#how-do-i-use-kubernetes-service-discovery-with-the-aurora-database)

### Major changes

- [Upgrading a DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.Upgrading.html)
- [Restoring from a DB snapshot](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html)

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
