# Route 53 Hosted Zones

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

This folder contains code to deploy [Route 53 Hosted Zones](https://aws.amazon.com/route53/) and
[AWS Cloud Map Namespaces](https://aws.amazon.com/cloud-map/) on AWS.

![Route 53 architecture](../../../_docs/route53-architecture.png?raw=true)

## Features

- Manage DNS entries using AWS Route 53 or AWS Cloud Map

- Optionally order and automatically verify ACM wildcard certificates for public zones

- Automatic health checks to route traffic only to healthy endpoints

- Automatic integration with other AWS services, such as ELBs

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [Should you use AWS Route 53 or CloudMap for your DNS entries?](core-concepts.md#should-i-use-route53-or-cloud-map)

- [AWS Cloud Map Documentation](https://docs.aws.amazon.com/cloud-map/latest/dg/what-is-cloud-map.html): Amazon’s docs for AWS Cloud Map that cover core concepts and configuration.

- [Route 53 Documentation](https://docs.aws.amazon.com/route53/): Amazon’s docs for Route 53 that cover core concepts and configuration.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code optimized for direct usage in production. This is code from the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

- [Route 53 Developer Guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html)

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers [Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you’re already a Gruntwork customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you’re not sure,
feel free to email us at <support@gruntwork.io>.

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes through our automated test suite.

Please see [Contributing to the Gruntwork Service Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#_contributing_to_the_gruntwork_infrastructure_as_code_library) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
