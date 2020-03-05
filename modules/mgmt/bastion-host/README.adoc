# Bastion Host

This Terraform Module creates a single EC2 instance that is meant to serve as a bastion host. A bastion host is a security best
practice where it is the *only* server exposed to the public. You must connect to it (e.g. via SSH) before you can
connect to any of your other servers, which are in private subnets. This way, you minimize the surface area you expose
to attackers, and can focus all your efforts on locking down just a single server.

The resources that are created by these templates include:

1. An AMI to run on the bastion host
1. The EC2 instance
1. An Elastic IP Address (EIP).
1. IAM Role and IAM instance profile.
1. Security group.

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[module-server](https://github.com/gruntwork-io/module-server) repo. If you don't have access to this repo, email
support@gruntwork.io.

## The bastion host AMI

The bastion host AMI is defined using the [Packer](https://www.packer.io/) template under `packer/bastion-host.json`.
This template configures the AMI to:

1. Run the [ssh-grunt module](https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt) so that
   developers can upload their public SSH keys to IAM and use those SSH keys, along with their IAM user names, to SSH
   to the bastion host.
1. Run the [auto-update module](https://github.com/gruntwork-io/module-security/tree/master/modules/auto-update) so
   that the bastion host installs security updates automatically.
{{- if .InstallCloudWatchMonitoring }}
1. Run the [syslog module](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/syslog) to
   automatically rotate and rate limit syslog so that the bastion host doesn't run out of disk space from large volumes
   of logs.
{{- end }}

## Known errors

When you run `terraform apply` on these templates the first time, you may see the following error:

```
* aws_iam_instance_profile.bastion: diffs didn't match during apply. This is a bug with Terraform and should be reported as a GitHub Issue.
```

As the error implies, this is a Terraform bug, but fortunately, it's a harmless one related to the fact that AWS is
eventually consistent, and Terraform occasionally tries to use a recently-created resource that isn't yet available.
Just re-run `terraform apply` and the error should go away.

## Core concepts

To understand core concepts like why you should use a bastion host, how to connect to the bastion host, how to use the
bastion host as a "jump host" to connect to other instances, port forwarding, and more, see the [bastion-host
documentation](https://github.com/gruntwork-io/module-server/tree/master/examples/bastion-host) documentation in the
[module-server](https://github.com/gruntwork-io/module-server) repo.
