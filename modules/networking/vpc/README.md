# VPC

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

This folder contains code to deploy a [Virtual Private Cloud (VPC)](https://aws.amazon.com/vpc) on AWS that can be used for either production or non-production workloads.

![VPC architecture](../../../_docs/vpc-subnets-diagram.png?raw=true)

## Features

- The VPC itself.

- Subnets, which are isolated subdivisions within the VPC. There are 3 "tiers" of subnets: public, private app, and private persistence.

- Route tables, which provide routing rules for the subnets.

- Internet Gateways to route traffic to the public Internet from public subnets.

- NATs to route traffic to the public Internet from private subnets.

- Optionally, VPC peering to a management VPC

- Optionally, DNS forwarding for a management VPC

- Optionally, tags for an EKS cluster

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-vpc](https://github.com/gruntwork-io/terraform-aws-vpc) repo. If you don’t have access to this repo, email <support@gruntwork.io>.

### Core concepts

To understand core concepts like what’s a VPC, how subnets are configured, how network ACLs work, and more, see the
documentation in the [terraform-aws-vpc](https://github.com/gruntwork-io/terraform-aws-vpc) repo.

### Repo organization

- [modules](/modules): The main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.

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

- [How to deploy a production-grade VPC on AWS](https://gruntwork.io/guides/networking/how-to-deploy-production-grade-vpc-aws)

- [How to configure a production-grade CI/CD workflow for application and infrastructure code](https://gruntwork.io/guides/automation-and-workflows/how-to-configure-a-production-grade-ci-cd-setup-for-apps-and-infrastructure-code/): step-by-step guide on how to configure CI / CD for your apps and infrastructure.

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers [Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you’re already a Gruntwork customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you’re not sure, feel free to email us at <support@gruntwork.io>.

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes through our automated test suite.

Please see [Contributing to the Gruntwork Service Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library/#contributing-to-the-gruntwork-infrastructure-as-code-library) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
