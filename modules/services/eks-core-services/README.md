# Amazon EKS Core Services

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)
![Helm version](https://img.shields.io/badge/helm-%3E%3D3.1.0-green)
![K8s version](https://img.shields.io/badge/k8s-1.16%20~%201.21-5dbcd2)

This folder contains [Terraform](https://www.terraform.io) and [Helm](https://helm.sh/) code to deploy core administrative
services, such as FluentD and the ALB Ingress Controller, onto [Elastic Kubernetes Service (EKS)](https://docs.aws.amazon.com/eks/latest/userguide/clusters.html).

![EKS Core Services architecture](/_docs/eks-core-services-architecture.png?raw=true)

## Features

- Deploy FluentD DaemonSet to ship container logs to CloudWatch Logs

- Deploy ALB Ingress Controller to configure ALBs from within Kubernetes

- Deploy external-dns to manage Route 53 DNS records from within Kubernetes

- Deploy Kubernetes cluster-autoscaler to configure auto scaling of ASGs based on Pod demand

- Deploy AWS CloudWatch Agent to configure container and node level metrics from worker nodes

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks) repo. If you don’t have access to this repo, email
<support@gruntwork.io>.

### Core concepts

For information on each of the core services deployed by this module, see the documentation in the
[terraform-aws-eks](https://github.com/gruntwork-io/terraform-aws-eks) repo.

- [FluentD DaemonSet](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-cloudwatch-container-logs)

- [ALB Ingress Controller](https://github.com/gruntwork-io/terraform-aws-eks/blob/master/modules/eks-alb-ingress-controller)

- [external-dns](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-k8s-external-dns)

- [cluster-autoscaler](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-k8s-cluster-autoscaler)

- [EKS CloudWatch Agent](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-cloudwatch-agent)

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

- [How to deploy a production-grade Kubernetes cluster on AWS](https://gruntwork.io/guides/kubernetes/how-to-deploy-production-grade-kubernetes-cluster-aws/#deployment_walkthrough): A step-by-step guide for deploying a production-grade EKS cluster on AWS using the code in this repo.

## Operate

- [How do you use the ingress controller to translate Ingress resources into ALBs?](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-alb-ingress-controller#using-the-ingress-controller)

- [How do I hook up the cluster autoscaler to my workers?](core-concepts.md#how-do-i-hook-up-the-cluster-autoscaler-to-my-workers)

- [How do I restrict which Hosted Zones the app should manage?](core-concepts.md#how-do-i-restrict-which-hosted-zones-the-app-should-manage)

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes through our automated test suite.

Please see [Contributing to the Gruntwork Infrastructure as Code Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library/#contributing-to-the-gruntwork-infrastructure-as-code-library) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.