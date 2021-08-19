# OpenVPN Server

This directory deploys and manages an [OpenVPN Server](https://openvpn.net/). This server acts as the entrypoint to your
AWS account. You must connect to it (e.g. via a VPN tunnel) before you can connect to any of your other servers, which are in
private subnets. This way, you minimize the surface area you expose to attackers, and can focus all your efforts on
locking down just a single server.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

Note that this module depends on the AMI defined by the [Packer](https://www.packer.io) template in [the
module](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.58.0/modules/mgmt/openvpn-server/openvpn-server.json).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.58.0/modules/mgmt/openvpn-server) for more
information about the underlying Terraform module.
