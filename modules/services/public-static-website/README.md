---
type: service
name: Public Static Website
description: Deploy your static content and static websites on S3, using a CloudFront CDN. Supports bucket versioning, redirects, and access logging.
category: static-website
cloud: aws
tags: ["cloudfront", "s3", "website", "static-website"]
license: gruntwork
built-with: terraform
---

# Public Static Website

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service creates a public static website using [S3](https://docs.aws.amazon.com/s3/index.html) and
[CloudFront](https://docs.aws.amazon.com/cloudfront/index.html) on [AWS](https://aws.amazon.com). The website can
contain static HTML, CSS, JS, and images.

![Static S3 Website](/_docs/s3-architecture.png?raw=true)

## Features

- Offload storage and serving of static content (HTML, CSS, JS, images) to a public S3 bucket configured as a website.
- Create additional buckets to store your website access logs, and your CloudFront access logs.
- Deploy a CloudFront Distribution in front of the public S3 bucket for your website domain.
- Optionally:

  - Create a Route 53 entry in IPV4 and IPV6 formats to route requests to your domain name to the public S3 bucket,
  - And associate an existing TLS certificate issued by Amazon’s Certificate Manager (ACM) for your domain.

## Learn

Serving static content from S3 rather than from your own app server can significantly reduce the load on your server,
allowing it to focus on serving dynamic data. This saves money and makes your website run faster. For even bigger
improvements in performance, deploy a CloudFront Content Distribution Network (CDN) in front of the S3 bucket.

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

This module deploys a public website, so the S3 bucket and objects with it are readable by the public. It also is
hosted in a Public Hosted Zone in Route 53. You may provide a `hosted_zone_id` in [variables](./variables.tf),
or you may provide the `base_domain_name` associated with your Public Hosted Zone in Route 53, optionally along with
any tags that must match that zone in `base_domain_name_tags`. If you do the latter, this module will find the hosted
zone id for you.

For more info on why you would use S3 to store static content, why you may want a CDN in front of it, how to access the
website, and how to configure SSL, check out the documentation for the
[s3-static-website](https://github.com/gruntwork-io/terraform-aws-static-assets/tree/master/modules/s3-static-website)
and [s3-cloudfront](https://github.com/gruntwork-io/terraform-aws-static-assets/tree/master/modules/s3-cloudfront)
modules.

- [Quick Start](/modules/services/public-static-website/core-concepts.md#quick-start)
- [How to test the website](https://github.com/gruntwork-io/terraform-aws-static-assets/blob/master/modules/s3-static-website/core-concepts.md#how-to-test-the-website)
- [How to configure HTTPS (SSL) or a CDN?](/modules/services/public-static-website/core-concepts.md#how-to-configure-https-ssl-or-a-cdn)
- [How to handle www + root domains](https://github.com/gruntwork-io/terraform-aws-static-assets/blob/master/modules/s3-static-website/core-concepts.md#how-do-i-handle-www—root-domains)
- [How do I configure Cross Origin Resource Sharing (CORS)?](https://github.com/gruntwork-io/terraform-aws-static-assets/blob/master/modules/s3-static-website/core-concepts.md#how-do-i-configure-cross-origin-resource-sharing-cors)

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

- [examples/for-production folder](/examples/for-learning-and-testing/services/public-static-website/example-website):
  The `examples/for-production` folder contains sample code optimized for direct usage in production. This is code from
  the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

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
