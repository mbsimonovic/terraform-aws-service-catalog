# 3-Tier VPC

This directory creates a 3-Tier [Virtual Private Cloud (VPC)](https://aws.amazon.com/vpc/) that can be used for either
production or non-production workloads.

The resources that are created include:

1. The VPC itself.
1. Subnets, which are isolated subdivisions within the VPC. There are 3 "tiers" of subnets: public, private app, and
   private persistence.
1. Route tables, which provide routing rules for the subnets.
1. Internet Gateways to route traffic to the public Internet from public subnets.
1. NATs to route traffic to the public Internet from private subnets.
1. Network ACLs that control what traffic can go in and out of each subnet.
1. VPC Peering connection that allows limited access from the Mgmt VPC.

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[module-vpc](https://github.com/gruntwork-io/module-vpc) repo. If you don't have access to this repo, email
support@gruntwork.io.

## Core concepts

To understand core concepts like what's a VPC, how subnets are configured, how network ACLs work, and more, see the
documentation in the [module-vpc](https://github.com/gruntwork-io/module-vpc) repo.