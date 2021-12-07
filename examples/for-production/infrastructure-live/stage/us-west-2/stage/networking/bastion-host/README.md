# Bastion Host

This directory deploys and manages a basic Linux host that can be used as an SSH bastion host. A bastion host is a
security best practice where it is the only server exposed to the public. You must connect to it (e.g. via SSH) before
you can connect to any of your other servers, which are in private subnets. This way, you minimize the surface area you
expose to attackers, and can focus all your efforts on locking down just a single server.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

Note that this module depends on the AMI defined by the [Packer](https://www.packer.io) template in [the
module](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.65.0/modules/mgmt/bastion-host/bastion-host.json).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.65.0/modules/mgmt/bastion-host) for more
information about the underlying Terraform module.
