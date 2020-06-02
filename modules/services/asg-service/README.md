# Auto Scaling Group Service Module

This Terraform Module deploys  a service on top of an Auto Scaling Group (ASG). It also deploys an Application Load
Balancer (ALB) in front of the service to route traffic across the ASG.

## How do you use this module?

* See the [root README](/README.md) for instructions on how to deploy the Terraform code in this repo.
* See [variables.tf](./variables.tf) for all the variables you can set on this module.

## What's an Auto Scaling Group?

An [Auto Scaling Group](https://aws.amazon.com/autoscaling/) (ASG) is used to manage a cluster of EC2 Instances. It
can enforce pre-defined rules about how many instances to run in the cluster, scale the number of instances up or
down depending on traffic, and automatically restart instances if they go down.

## How does rolling deployment work?

Since Terraform does not have rolling deployment built in (see https://github.com/hashicorp/terraform/issues/1552), we
are faking it using the `create_before_destroy` lifecycle property. This approach is based on the rolling deploy
strategy used by HashiCorp itself, [as described by Paul Hinze
here](https://groups.google.com/forum/#!msg/terraform-tool/7Gdhv1OAc80/iNQ93riiLwAJ). As a result, every time you
update your launch configuration (e.g. by specifying a new AMI to deploy), Terraform will:

1. Create a new ASG of the same size with the new launch configuration.
1. Wait for the new ASG to deploy successfully and for the instances to register with the ELB (if you associated an ELB
   with this ASG).
1. Destroy the old ASG.
1. Since the old ASG is only removed once the new ASG instances are registered with the ELB and serving traffic, there
   will be no downtime. Moreover, if anything went wrong while rolling out the new ASG, it will be marked as
   [tainted](https://www.terraform.io/docs/commands/taint.html) (i.e. marked for deletion next time) and the original
   ASG will be left unchanged, so again, there is no downtime.

## Core concepts

For more info on Auto Scaling Groups, `create_before_destroy`, and more, check out the [asg-rolling-deploy
module](https://github.com/gruntwork-io/module-asg/tree/master/modules/asg-rolling-deploy) in the
[module-asg repo](https://github.com/gruntwork-io/module-asg).
