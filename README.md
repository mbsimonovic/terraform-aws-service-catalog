# Gruntwork Service Catalog for AWS

This repo contains the code for the Gruntwork Service Catalog for AWS. It consists of a number of reusable, 
customizable, battle-tested, production-grade [infrastructure-as-code services](/modules) that you can use to deploy 
and manage your infrastructure, including Docker orchestration, EC2 orchestration, load balancing, networking, 
databases, caches, monitoring, alerting, CI/CD, secrets management, VPN, and much more. Under the hood, these services 
are built using modules from the [Gruntwork Infrastructure as Code 
Library](https://gruntwork.io/infrastructure-as-code-library/). 




## Features

* Deploy production-grade infrastructure in minutes by using off-the-shelf, battle-tested services.
* Build on top of infrastructure code that has been proven in production at hundreds of companies and is commercially
  supported and maintained by Gruntwork.
* Each service exposes a number of input variables that give you deep control over its behavior: e.g., what VPCs and
  subnets to use, what to do for log aggregation, how to manage SSH and VPN access, how to manage secrets, and so on.
* Each service is defined as code, so you can customize the behavior even further by either extending or forking the  
  module.



## Learn

* [Gruntwork Service Catalog Overview](core-concepts.md#gruntwork-service-catalog-overview)
* [How to deploy new infrastructure from the Service Catalog](core-concepts.md#deploy-new-infrastructure)
* [How to update infrastructure from the Service Catalog](core-concepts.md#make-changes-to-your-infrastructure)
* [How to create your own Service Catalog](core-concepts.md#create-your-own-service-catalog)




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

## Development - pre-commit requirements 

This repo makes use of [pre-commit](https://pre-commit.com/) to help catch formatting and syntax issues client-side prior to code reviews. Gruntwork maintains [a collection of pre-commit hooks](https://github.com/gruntwork-io/pre-commit) that are specifically tailored to languages and tooling we commonly use.  

Before contributing to this repo: 

1. [Install pre-commit](https://pre-commit.com/#installation)
1. After cloning the repository, run `pre-commit install` in your local working directory 
1. You can examine the `.pre-commit-config.yml` file to see the hooks that will be installed and run when the git pre-commit hook is invoked. 
1. Python version >= 3.7 is required to run the hook scripts without issues. We recommend using [pyenv](https://realpython.com/intro-to-pyenv/) to manage multiple versions of Python on your system.
1. Once everything is working properly, you will notice that several checks are being run locally each time you run `git commit`. Note that your commit will not succeed until all `pre-commit` checks pass. 

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers
[Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you're already a Gruntwork
customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you're not sure,
feel free to email us at [support@gruntwork.io](mailto:support@gruntwork.io).




## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even
contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.

Please see [Contributing to the Gruntwork Service Catalog](core-concepts.md#contributing-to-the-gruntwork-service-catalog)
for instructions.




## License

Please see [LICENSE.txt](LICENSE.txt) for details on how the code in this repo is licensed.
