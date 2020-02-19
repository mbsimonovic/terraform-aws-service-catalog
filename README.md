# Gruntwork Service Catalog for AWS

This repo contains the code for the [Gruntwork Service Catalog](https://gruntwork.io/service-catalog/) for AWS. It 
consists of a number of reusable, customizable, battle-tested [infrastructure-as-code modules](/modules) that you can 
use to deploy your production infrastructure, including Docker orchestration, EC2 orchestration, load balancing, 
networking, databases, caches, monitoring, alerting, CI/CD, secrets management, VPN, and much more. 




## Features

* Deploy production-grade infrastructure in minutes by using off-the-shelf, battle-tested components.
* Build on top of infrastructure code that has been proven in production at hundreds of companies and is commercially
  supported and maintained by Gruntwork.
* Each module exposes a number of input variables that give you deep control over its behavior: e.g., what VPCs and
  subnets to use, what to do for log aggregation, how to manage SSH and VPN access, how to manage secrets, and so on.
* Each module is defined as code, so you can customize the behavior even further by either extending or forking the  
  module.



## Learn

### Core concepts

* https://gruntwork.io/guides/foundations/how-to-use-gruntwork-service-catallog/[How to use the Gruntwork Service Catalog]

### Repo organization

* [modules](/modules): The main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.
* [examples](/examples): This folder contains working examples of how to use the submodules.
* [test](/test): Automated tests for the modules and examples.



## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

* [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
  `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and
  testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

* [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample
  code optimized for direct usage in production. This is code from the [Gruntwork Reference
  Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an end-to-end, integrated
  tech stack on top of the Gruntwork Service Catalog.




## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers
[Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you're already a Gruntwork
customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you're not sure,
feel free to email us at [support@gruntwork.io](mailto:support@gruntwork.io).




## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even
contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.

Please see [Contributing to the Gruntwork Service 
Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-service-catalog/#contributing-to-the-gruntwork-service-catalog)
for instructions.




## License

Please see [LICENSE.txt](LICENSE.txt) for details on how the code in this repo is licensed.
