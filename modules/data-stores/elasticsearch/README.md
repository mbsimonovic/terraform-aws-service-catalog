---
type: service
name: Amazon Elasticsearch
description: Deploy and manage Amazon Elasticsearch Service.
category: nosql
cloud: aws
tags: ["analytics", "data"]
license: gruntwork
built-with: terraform
---

# Amazon Elasticsearch Service

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

## Overview

This service contains code to deploy an Amazon Elasticsearch Service cluster.
See the [Amazon Elasticsearch Service documentation](http://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html)
and the [Getting Started](https://aws.amazon.com/elasticsearch-service/getting-started/) page for more information.

## Features

- A fully-managed native Elasticsearch cluster in a VPC
- A fully functional Kibana UI
- VPC-based security
- Zone awareness, i.e., deployment of Elasticsearch nodes across Availability Zones
- Automatic nightly snapshots
- CloudWatch Alarms for alerting when CPU, memory, and disk metrics exceed certain thresholds

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [About Amazon Elasticsearch Service](https://aws.amazon.com/elasticsearch-service/)
- [Features of Amazon ES](https://aws.amazon.com/elasticsearch-service/features/)
- [Developer Guide](https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/what-is-amazon-elasticsearch-service.html):
  Contains the main documentation on how to use Amazon ES and answers questions such as "What is Amazon Elasticsearch
  Service?"
- [Streaming CloudWatch monitoring logs to Amazon Elasticsearch Service](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_ES_Stream.html)

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
  `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and
  testing (but not direct production usage).

- [AWS Free tier](https://aws.amazon.com/free/): Using Amazon ES on Amazon’s free tier is a great way to get started,
  but it has limited features and does not include encryption at rest, ultra warm data notes, or advanced security
  options such as fine-grained access control. The free tier does allow multiple availability zones, VPC-based access
  control, TLS-only requests, and node-to-node encryption.

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code
  optimized for direct usage in production. This is code from the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/),
  and it shows you how we build an end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

- [Amazon Elasticsearch Service pricing](https://aws.amazon.com/elasticsearch-service/pricing/)

## Operate

### Day-to-day operations

- [Open Distro docs: How to index data into Elasticsearch](https://opendistro.github.io/for-elasticsearch-docs/docs/elasticsearch/index-data/):
  Documentation by Open Distro for Elasticsearch, a reliable resource on how to use Elasticsearch APIs.
- [Elastic docs: How to index data into Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-index_.html):
  Documentation by Elastic, the originators of Elasticsearch.
- [How to size Amazon ES domains](https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/sizing-domains.html)

### Major changes

- [Upgrading Elasticsearch](https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-version-migration.html)
- [Using Snapshot / Restore](https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-managedomains-snapshots.html)

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
