---
type: service
name: S3 Bucket
description: Deploy an S3 bucket for data storage, with support for access logging, versioning and replication.
category: data-store
cloud: aws
tags: ["s3", "data", "storage"]
license: gruntwork
built-with: terraform
---

# S3 Bucket

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service contains code to deploy an [S3 bucket](https://aws.amazon.com/s3/) on AWS.

![S3 bucket architecture](../../../_docs/s3-bucket-architecture.png?raw=true)

## Features

- Deploy a private, secure S3 bucket
- Configure access logging to another S3 bucket
- Configure object versioning
- Configure cross-region replication

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [Gruntwork private-s3-bucket module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/private-s3-bucket): The underlying module that implements the private S3 bucket functionality.

- [S3 Documentation](https://docs.aws.amazon.com/AmazonS3/latest/gsg/GetStartedWithS3.html): Amazon’s docs for S3 that
  cover core concepts such as creating, accessing, copying and deleting buckets.

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

- [How to enable MFA Delete?](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/private-s3-bucket#how-do-you-enable-mfa-delete): step-by-step guide on enabling MFA delete for your S3 buckets.

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
