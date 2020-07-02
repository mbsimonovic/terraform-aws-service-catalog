# {{ .EcsServiceModuleName | capitalize }} Module

This Terraform Module deploys ECS Services that fit the  {{ .EcsServiceModuleName }} profile as an ECS Service on top 
of an ECS Cluster.

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules in this repo.
* See [variables.tf](./variables.tf) for all the variables you can set on this module.

## What is an ECS Cluster?

To use ECS, you first deploy one or more EC2 Instances into a "cluster". The ECS scheduler can then deploy Docker
containers across any of the instances in this cluster. Each instance needs to have the [Amazon ECS
Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) installed so it can communicate with
ECS and register itself as part of the right cluster.

## What is an ECS Service?

To run Docker containers with ECS, you first define an [ECS
Task](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_defintions.html), which is a JSON file that
describes what container(s) to run, the resources (memory, CPU) those containers need, the volumes to mount, the
environment variables to set, and so on. To actually run an ECS Task, you define an ECS Service, which can:

1. Deploy the requested number of Tasks across an ECS cluster based on the `desired_number_of_tasks` input variable.
1. Restart tasks if they fail.
1. Route traffic across the tasks with an optional Elastic Load Balancer (ELB). To use an ELB, set `is_associated_with_elb`
   to `true` and pass in the ELB details using the `elb_name`, `elb_container_name`, and `elb_container_port`
   input variables.

## Core concepts

For more info on ECS services and clusters, check out the
[ecs-cluster](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-cluster) and
[ecs-service](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-service) documentation in the
[module-ecs repo](https://github.com/gruntwork-io/module-ecs).
