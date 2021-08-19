# EC2 based ECS Cluster

This directory creates a [Elastic Container Service cluster](https://aws.amazon.com/ecs/) backed by EC2
instances. The resources created by this module are:

1. The **ECS cluster** for housing ECS tasks and services.
1. An **AWS Autoscaling Group** for managing EC2 instances that are registered as **ECS container instances**.
1. A **Security Group** to limit access to the ECS cluster.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.58.0/modules/services/ecs-cluster) for more
information about the underlying Terraform module.
