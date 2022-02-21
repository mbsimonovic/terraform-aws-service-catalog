---
type: service
name: Kubernetes Namespace
description: Provision a best practices Kubernetes Namespace on any Kubernetes Cluster.
category: docker-orchestration
cloud: aws
tags: ["docker", "orchestration", "kubernetes", "containers"]
license: gruntwork
built-with: terraform
---

# Kubernetes Namespace

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)

## Overview

This service contains [Terraform](https://www.terraform.io) code to provision a best practices
[Kubernetes Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/).

## Features

- Target any Kubernetes cluster (e.g., EKS, GKE, minikube, etc)
- Provision a set of default best practices RBAC roles for managing access to the Namespace
- Optionally configure Fargate Profile to schedule all Pods on EKS Fargate

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-kubernetes-namespace](https://github.com/gruntwork-io/terraform-kubernetes-namespace) repo. If you are a
subscriber and don’t have access to this repo, email <support@gruntwork.io>.

### Core concepts

- [Official documentation on Namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/):
  learn about the basics of Kubernetes Namespaces including what they are, how to interact with Namespaces, how DNS
  works, and when to use Namespaces.

- [Official documentation on RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/): learn about
  Kubernetes RBAC including what they are, what resources are involved, how they work, how to bind roles to users, and
  more.

- [Amazon’s documentation on Fargate](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html): learn about AWS
  EKS Fargate including what they are, how it works, limitations of Fargate, and more.

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
