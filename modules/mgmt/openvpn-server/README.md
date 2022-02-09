# OpenVPN Server

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

This Terraform Module deploys an [OpenVPN Server](https://openvpn.net/).

![OpenVPN server architecture](../../../_docs/openvpn-architecture.png?raw=true)

This server acts as the entrypoint to the VPC in which it is deployed. You must connect to it with an OpenVPN client
before you can connect to any of your other servers, which are in private subnets. This way, you minimize the surface
area you expose to attackers, and can focus all your efforts on locking down just a single server.

## Features

- An AMI to run on the OpenVPN Server

- An Auto Scaling Group of size 1 (for fault tolerance)

- An Elastic IP Address (EIP)

- IAM Role and IAM instance profile

- Security group.

- A DNS record

- Harden the OS by installing `fail2ban`, `ntp`, `auto-update`, `ip-lockdown`, and more

- Send all logs and metrics to CloudWatch

- Configure alerts in CloudWatch for CPU, memory, and disk space usage

- Manage SSH access with IAM groups using `ssh-grunt`

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[terraform-aws-openvpn](https://github.com/gruntwork-io/terraform-aws-openvpn) repo.

## Learn

> **NOTE**
This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/), a collection of reusable, battle-tested, production ready infrastructure code. If you’ve never used the Service Catalog before, make
sure to read [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

To understand core concepts like why you should use an OpenVPN server, how to connect to the vpn, how to use the
VPN server to connect to other systems on the AWS VPC, see the [openvpn-server
documentation](https://github.com/gruntwork-io/terraform-aws-openvpn/blob/master/modules/openvpn-server/README.md) documentation in the [package-openvpn](https://github.com/gruntwork-io/terraform-aws-openvpn) repo.

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
    [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture/), and it shows you how we build an
    end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.
    configure CI / CD for your apps and infrastructure.

## Operate

### Day-to-day operations

- [`fail2ban`](https://github.com/fail2ban/fail2ban) bans IP addresses that cause too many failed login attempts. The OpenVPN server is configured with `fail2ban` as a security measure. See the [`fail2ban` module](https://github.com/gruntwork-io/terraform-aws-security/tree/master/modules/fail2ban) for more information.

- Use the [openvpn-admin](https://github.com/gruntwork-io/terraform-aws-openvpn/blob/master/modules/openvpn-admin/README.md) utility to requests new certificates and, for administrators, to revoke existing certificates.

- The [`backup-openvpn-pki`](https://github.com/gruntwork-io/terraform-aws-openvpn/blob/master/modules/backup-openvpn-pki/README.md) module is used to backup the OpenVPN server’s PKI to an S3 bucket. See the module documentation for more information.

- We recommend the [Tunnelblick](https://tunnelblick.net/) (Mac) or [Viscosity](https://www.sparklabs.com/viscosity/) (Mac and Windows) VPN clients

- For debugging, use the logs found in `/var/log/user-data.log` on the OpenVPN server instance (for problems with initializing new server instances), and examine CloudWatch Logs (for other issues).

## Support

If you need help with this repo or anything else related to infrastructure or DevOps, Gruntwork offers
[Commercial Support](https://gruntwork.io/support/) via Slack, email, and phone/video. If you’re already a Gruntwork
customer, hop on Slack and ask away! If not, [subscribe now](https://www.gruntwork.io/pricing/). If you’re not sure, feel free to email us at <support@gruntwork.io>.

## Contributions

Contributions to this repo are very welcome and appreciated! If you find a bug or want to add a new feature or even
contribute an entirely new module, we are very happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.

Please see [Contributing to the Gruntwork Service Catalog](https://gruntwork.io/guides/foundations/how-to-use-gruntwork-infrastructure-as-code-library#_contributing_to_the_gruntwork_infrastructure_as_code_library) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
