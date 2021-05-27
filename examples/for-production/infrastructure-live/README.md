# Live infrastructure

This repository contains code to deploy infrastructure across all live environments in AWS. This code implements the
[Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/) using services from the [Gruntwork
AWS Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog).

![Reference Architecture](docs/images/landing-zone-ref-arch.png?raw=true)



## Learn

### Core concepts

* [Reference Architecture Walkthrough Documentation](/docs): Comprehensive documentation that walks through all
  aspects of this architecture, including what's deployed, how the code is organized, how to run the code in dev,
  how the CI / CD pipeline works, how to access metrics and logs, how to connect via VPN and SSH, and much more.
* [How to Build an End to End Production-Grade Architecture on AWS](https://blog.gruntwork.io/how-to-build-an-end-to-end-production-grade-architecture-on-aws-part-1-eae8eeb41fec):
  A blog post series that discusses the basic principles behind the Reference Architecture.
* [How to use the Gruntwork Infrastructure as Code Library](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library/):
  The Service Catalog is built on top of the [Gruntwork Infrastructure as Code
  Library](https://gruntwork.io/infrastructure-as-code-library/). Check out this guide to learn what the library is and
  how to use it.
* [How to configure a production-grade CI-CD workflow for infrastructure code](https://gruntwork.io/guides/automations/how-to-configure-a-production-grade-ci-cd-setup-for-apps-and-infrastructure-code/): A comprehensive guide on the Gruntwork Continuous Integration and Continuous Delivery pipeline for infrastructure code.
* [Gruntwork Production Deployment Guides](https://gruntwork.io/guides/): Additional step-by-step guides that show you how to go
  to production on top of AWS.
* [Overview](/docs/01-overview.md): An overview of what this repository is.



## Deploy

### Deploy updates

If you want to deploy updates to this infrastructure, check out the following resources:

* [Deploying app changes](/docs/03-deploy-apps.md): Instructions on how to deploy changes to an app, such as a Java/Ruby/Python web service packaged with Docker or Packer.
* [Deploying infrastructure changes](/docs/04-configure-ci-cd.md): Instructions on how to deploy changes to infrastructure code, such as Terraform modules that configure your VPCs, databases, DNS settings, etc.
* [Undeploying the Reference Architecture](/docs/06-undeploy.md): Instructions on how to
  undeploy the Reference Architecture completely.


## Manage

### Day-to-day operations

* [How to authenticate to AWS](docs/02-authenticate.md)
* [How to connect via VPN](/docs/02-authenticate.md#authenticate-to-the-vpn-server)
* [How to view metrics, logs, and alerts](/docs/05-monitoring-alerting-logging.md)



## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers [Commercial
Support](https://gruntwork.io/support/) via Slack, email, and video conference. If you have questions, feel free to
email us at [support@gruntwork.io](mailto:support@gruntwork.io).
