# EC2 Instance

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

This Terraform Module creates a single EC2 instance that includes server hardening, IAM role, EIP (optional), EBS Volume (optional), and CloudWatch metrics, logs, and alerts. Note that a single EC2 instance can be a single point of failure, so if you want to run multiple EC2 instances for high availability and scalability, see the \[asg-service\](/modules/services/asg-service).

## Features

- Build an AMI to run on the EC2 instance

- Create EC2 instance for the host

- Allocate an optional Elastic IP Address (EIP) and an associated DNS record

- Create an IAM Role and IAM instance profile

- Create a security group to manage ingress and egress traffic on desired ports

- Harden the OS by installing `fail2ban`, `ntp`, `auto-update`, `ip-lockdown`, and more

- Send all logs and metrics to CloudWatch

- Configure alerts in CloudWatch for CPU, memory, and disk space usage

- Manage SSH access with IAM groups using `ssh-grunt`

- Create and mount optional EBS volumes

- Allow ingress traffic on desired ports

## Learn

> **NOTE**
This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/), a collection of reusable, battle-tested, production ready infrastructure code. If you’ve never used the Service Catalog before, make
sure to read [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

- [How do I update my instance?](core-concepts.md#how-do-i-update-my-instance)

- [How do I use User Data?](core-concepts.md#how-do-i-use-user-data)

- [How do I mount an EBS volume?](core-concepts.md#how-do-i-mount-an-ebs-volume)

### The EC2 Instance AMI

The EC2 Instance AMI is defined using the [Packer](https://www.packer.io/) template at `ec2-instance.json`.
This template configures the AMI to:

1. Run the [ssh-grunt module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/ssh-grunt) so that developers can upload their public SSH keys to IAM and use those SSH keys, along with their IAM user names, to SSH to the EC2 instance.

2. Run the [auto-update module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/auto-update) so that the EC2 instance installs security updates automatically.

3. Optionally run the [syslog module](https://github.com/gruntwork-io/terraform-aws-monitoring/tree/master/modules/logs/syslog) to automatically rotate and rate limit syslog so that the EC2 instance doesn’t run out of disk space from large volumes of logs.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code optimized for direct usage in production. This is code from the [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an end-to-end, integrated tech stack on top of the Gruntwork Service Catalog, configure CI / CD for your apps and infrastructure.

## Operate

### Day-to-day operations

- [`fail2ban`](https://github.com/fail2ban/fail2ban) bans IP addresses that cause too many failed login attempts. The EC2 instance is configured with `fail2ban` as a security measure. See the [`fail2ban` module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/fail2ban) for more information.

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers [Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you’re already a Gruntwork customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you’re not sure,
feel free to email us at <support@gruntwork.io>.

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even
contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.

Please see [Contributing to the Gruntwork Service Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#_contributing_to_the_gruntwork_infrastructure_as_code_library)
for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
