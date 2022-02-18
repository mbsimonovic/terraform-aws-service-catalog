---
type: service
name: ECS Deploy Runner
description: Use a CI/CD pipeline for deploying infrastructure code updates.
category: ci-cd
cloud: aws
tags: ["ci-cd", "pipelines", "ci", "cd"]
license: gruntwork
built-with: terraform, bash, packer
---

# ECS Deploy Runner

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

## Overview

This service deploys ECS Deploy Runner, the central component of [Gruntwork Pipelines](https://gruntwork.io/pipelines).

![Gruntwork Pipelines architecture](../../../_docs/pipelines-architecture.png?raw=true)

Gruntwork Pipelines is a code framework and approach that enables you to use your preferred CI tool to set up an
end-to-end pipeline for infrastructure code (Terraform) and app code packaged in multiple formats, including container
images (Docker) and Amazon Machine Images (AMIs built with Packer).

## Features

- Set up a Terraform and Terragrunt pipeline based on best practices
- Run deployments using Fargate or EC2 tasks on the ECS cluster
- Configure the pipeline for building Packer and Docker images and for running `plan` and `apply` operations
- Grant fine-grained permissions for running deployments with minimum necessary privileges
- Stream output from the pipeline to CloudWatch Logs
- Protect secrets needed by the pipeline using AWS Secrets Manager
- Use KMS grants to allow the ECS task containers to access shared secrets and encrypted images between accounts
- Easily upgrade Terraform versions with Terraform version management support

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-ci](https://github.com/gruntwork-io/terraform-aws-ci) repo.

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

- For a comprehensive guide to Gruntwork Pipelines, refer to
  [How to configure a production-grade CI-CD workflow for infrastructure code](https://docs.gruntwork.io/guides/build-it-yourself/pipelines/).
- For an overview of how the various parts fit together to form the complete pipeline, refer to the
  [ECS Deploy Runner Core Concepts](https://github.com/gruntwork-io/terraform-aws-ci/blob/master/modules/ecs-deploy-runner/core-concepts.md#overview).
- The rest of the docs within the
  [ecs-deploy-runner module in the terraform-aws-ci repository](https://github.com/gruntwork-io/terraform-aws-ci/blob/master/modules/ecs-deploy-runner/README.adoc)
  may also help with context.
- The [ECS Deploy Runner standard configuration](https://github.com/gruntwork-io/terraform-aws-ci/blob/master/modules/ecs-deploy-runner-standard-configuration/README.md)
  is a shortcut for setting up the `ecs-deploy-runner` module in a manner consistent with Gruntwork recommendations.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
  `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and
  testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [shared account ecs-deploy-runner configuration in the for-production folder](/examples/for-production/infrastructure-live/shared/us-west-2/mgmt/ecs-deploy-runner/):
  The `examples/for-production` folder contains sample code optimized for direct usage in production. This is code from
  the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

### Day-to-day operations

- To upgrade the Docker image used by the pipeline, use the
  [deploy-runner Dockerfile](https://github.com/gruntwork-io/terraform-aws-ci/blob/master/modules/ecs-deploy-runner/docker/deploy-runner/Dockerfile)
  and the [Kaniko Dockerfile](https://github.com/gruntwork-io/terraform-aws-ci/blob/master/modules/ecs-deploy-runner/docker/kaniko/Dockerfile)
  (used when building Docker images in the pipeline)
- For examples of how to invoke the pipeline to build AMIs, refer to the
  [AMI build scripts in the for-production examples](/examples/for-production/infrastructure-live/shared/us-west-2/_regional/amis)
- For examples of how to invoke the pipeline to build Docker images, refer to the
  [container image build scripts in the for-production examples](/examples/for-production/infrastructure-live/shared/us-west-2/_regional/container_images)
- To see how to use the pipeline with CircleCI, see the [`.circleci/config.yml` example](/examples/for-production/infrastructure-live/.circleci/config.yml)
- There is also [a collection of scripts](/examples/for-production/infrastructure-live/_ci/scripts) for invoking the
  ecs-deploy-runner with any CI/CD system. These scripts are used in the circleci config, but can also be used with
  Jenkins, GitHub Actions, etc.
- The ecs-deploy-runner supports running with multiple versions of Terraform to help you incrementally upgrade your
  infrastructure. Learn more about this in the
  [deploy-runner documentation](https://github.com/gruntwork-io/terraform-aws-ci/blob/master/modules/ecs-deploy-runner/core-concepts.md#how-do-i-use-the-deploy-runner-with-multiple-terraform-versions).

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
