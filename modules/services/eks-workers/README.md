---
type: service
name: Amazon EKS Workers
description: Deploy EC2 instances as Kubernetes workers for Amazon Elastic Kubernetes Service (EKS).
category: docker-orchestration
cloud: aws
tags: ["docker", "orchestration", "kubernetes", "containers"]
license: gruntwork
built-with: terraform, bash, python, go
---

# Amazon EKS Workers

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)
![Helm version](https://img.shields.io/badge/helm-%3E%3D3.1.0-green)
![K8s version](https://img.shields.io/badge/k8s-1.16%20~%201.21-5dbcd2)

## Overview

This service contains [Terraform](https://www.terraform.io) and [Packer](https://www.packer.io) code to deploy a
production-grade EC2 server cluster as workers for
[Elastic Kubernetes Service (EKS)](https://docs.aws.amazon.com/eks/latest/userguide/clusters.html) on
[AWS](https://aws.amazon.com).

![EKS architecture](/_docs/eks-architecture.png?raw=true)

## Features

- Deploy self-managed worker nodes in an Auto Scaling Group
- Deploy managed workers nodes in a Managed Node Group
- Zero-downtime, rolling deployment for updating worker nodes
- Auto scaling and auto healing
- For Nodes:

  - Server-hardening with fail2ban, ip-lockdown, auto-update, and more
  - Manage SSH access via IAM groups via ssh-grunt
  - CloudWatch log aggregation
  - CloudWatch metrics and alerts

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks) repo. If you are a subscriber and don’t have
access to this repo, email <support@gruntwork.io>.

### Core concepts

To understand core concepts like what is Kubernetes, the different worker types, how to authenticate to Kubernetes, and
more, see the documentation in the [terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks) repo.

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

- [How to deploy a production-grade Kubernetes cluster on AWS](https://docs.gruntwork.io/guides/build-it-yourself/kubernetes-cluster/deployment-walkthrough/pre-requisites):
  A step-by-step guide for deploying a production-grade EKS cluster on AWS using the code in this repo.

## Manage

For information on registering the worker IAM role to the EKS control plane, refer to the
[IAM Roles and Kubernetes API Access](core-concepts.md#iam-roles-and-kubernetes-api-access) section of the documentation.

For information on how to perform a blue-green deployment of the worker pools, refer to the
[How do I perform a blue green release to roll out new versions of the module](core-concepts.md#how-do-i-perform-a-blue-green-release-to-roll-out-new-versions-of-the-module)
section of the documentation.

For information on how to manage your EKS cluster, including how to deploy Pods on Fargate, how to associate IAM roles
to Pod, how to upgrade your EKS cluster, and more, see the documentation in the
[terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks) repo.

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
