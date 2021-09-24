# EKS Cluster using EC2 instances

This directory creates a [Elastic Kubernetes Service cluster](https://aws.amazon.com/eks/) backed by EC2
instances. The resources created by this module are:

1. The **EKS cluster** for housing EKS core services and workers.
1. An **AWS Autoscaling Group** per availability zone, for managing EC2 instances that are registered as **EKS container instances**.
1. A **Security Group** to limit access to the EKS cluster.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.62.0/modules/services/eks-core-services) for more
information about the underlying Terraform module.
