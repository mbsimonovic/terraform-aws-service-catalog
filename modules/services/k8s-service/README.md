# Kubernetes Service

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)
![Helm version](https://img.shields.io/badge/helm-%3E%3D3.1.0-green)

This folder contains [Terraform](https://www.terraform.io) code to deploy your web application containers using
[the k8-service Gruntwork Helm Chart](https://github.com/gruntwork-io/helm-kubernetes-services/) on to
[Kubernetes](https://kubernetes.io/) following best practices.

![Kubernetes Service architecture](/_docs/k8s-service-architecture.png?raw=true)

## Features

- Deploy your application containers on to Kubernetes

- Zero-downtime rolling deployments

- Auto scaling and auto healing

- Configuration management and Secrets management

- Ingress and Service endpoints

- Service discovery with Kubernetes DNS

- Managed with Helm

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[helm-kubernetes-services](https://github.com/gruntwork-io/helm-kubernetes-services) repo. If you don’t have access to this repo, email
<support@gruntwork.io>.

### Core concepts

- [Kubernetes core concepts](https://gruntwork.io/guides/kubernetes/how-to-deploy-production-grade-kubernetes-cluster-aws/#core_concepts): learn about Kubernetes architecture (control plane, worker nodes), access control (authentication, authorization), resources (pods, controllers, services, config, secrets), and more.

- [How do you run applications on Kubernetes?](https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/core-concepts.md#how-do-you-run-applications-on-kubernetes)

- [What is Helm?](https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/core-concepts.md#what-is-helm)

- *[Kubernetes in Action](https://www.manning.com/books/kubernetes-in-action)*: the best book we’ve found for getting up and running with Kubernetes.

### Repo organization

- [modules](/modules): the main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.

- [examples](/examples): This folder contains working examples of how to use the submodules.

- [test](/test): Automated tests for the modules and examples.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
`examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code optimized for direct usage in production. This is code from the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

- [How do I expose my application?](core-concepts.md#how-do-i-expose-my-application)

- [How do I manage secrets and configurations for the application?](core-concepts.md#configuration-and-secrets-management)

- [How do I debug my configuration?](core-concepts.md#how-do-i-debug-my-configuration)

- [How do I create a canary deployment?](core-concepts.md#how-do-i-create-a-canary-deployment)

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes through our automated test suite.

Please see [Contributing to the Gruntwork Infrastructure as Code Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library/#contributing-to-the-gruntwork-infrastructure-as-code-library) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
