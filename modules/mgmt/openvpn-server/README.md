# OpenVPN Server

This Terraform Module deploys an [OpenVPN Server](https://openvpn.net/). This server acts as the entrypoint to your 
AWS account. You must connect to it with an OpenVPN client before you can connect to any of your other servers, which 
are in private subnets. This way, you minimize the surface area you expose to attackers, and can focus all your efforts 
on locking down just a single server.

The resources that are created by these templates include:

1. An AMI to run on the OpenVPN Server
1. An Auto Scaling Group of size 1 (for fault tolerance)
1. An Elastic IP Address (EIP).
1. IAM Role and IAM instance profile.
1. Security group.

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[package-openvpn](https://github.com/gruntwork-io/package-openvpn) repo. If you don't have access to this repo, email
support@gruntwork.io.





## The OpenVPN Server AMI

The OpenVPN Server AMI is defined using the [Packer](https://www.packer.io/) template under `packer/openvpn-server.json`.
This template configures the AMI to:

1. Install OpenVPN server, all its dependencies, and our admin tools.
1. Run the [ssh-grunt module](https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt) so that
   developers can upload their public SSH keys to IAM and use those SSH keys, along with their IAM user names, to SSH
   to the OpenVPN Server (typically for troubleshooting only).
1. Run the [auto-update module](https://github.com/gruntwork-io/module-security/tree/master/modules/auto-update) so
   that the OpenVPN Server installs security updates automatically.
{{- if .InstallCloudWatchMonitoring }}
1. Run the [syslog module](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/syslog) to
   automatically rotate and rate limit syslog so that the server doesn't run out of disk space from large volumes
   of logs.
{{- end }}




## Core concepts

To understand core concepts like why you should use an OpenVPN Server, how to connect to the server, how to manage
credentials, and more, see the [package-openvpn](https://github.com/gruntwork-io/package-openvpn) repo.
