# Application Load Balancer

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

This folder contains code to deploy [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/) on AWS.

![ALB architecture](../../../_docs/alb-architecture.png?raw=true)

## Features

- Deploy public or internal Application Load Balancers

- Configure DNS in Route 53

- Configure TLS in AWS Certificate Manager (ACM)

- Send access logs into S3

- Manage access with security groups or CIDR blocks

## Learn

> **NOTE**
This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/), a collection of reusable, battle-tested, production ready infrastructure code. If you’ve never used the Service Catalog before, make sure to read [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

- [Gruntwork Documentation on ALBs](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/master/modules/alb#background): Background information from Gruntwork about ALBs including what it is, differences from other ELB flavors, and when you should use ALBs.

- [ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html): Amazon’s docs for ALB that cover core concepts such as listeners, target groups, autoscaling, TLS and migrations.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
    `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and
    testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample
    code optimized for direct usage in production. This is code from the
    [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an
    end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

- [How do I route to ECS?](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/master/modules/alb#using-the-alb-with-ecs)

- [What routes should I configure for each listener?](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/master/modules/alb#make-sure-your-listeners-handle-all-possible-request-paths)

- [How do I handle overlapping routes?](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/master/modules/alb#make-sure-your-listener-rules-each-have-a-unique-priority)

- [How do I view the access logs?](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/load-balancer-access-logs#viewing-and-accessing-log-files)

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers
[Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you’re already a Gruntwork
customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you’re not sure,
feel free to email us at <support@gruntwork.io>.

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even
contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.

Please see
[Contributing to the Gruntwork Service Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#_contributing_to_the_gruntwork_infrastructure_as_code_library)
for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
