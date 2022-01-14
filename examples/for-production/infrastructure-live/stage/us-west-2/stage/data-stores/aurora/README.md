# RDS Aurora Cluster

This directory creates an [RDS Aurora](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html)
Cluster. The resources that are created include:

1. The RDS Aurora cluster, comprising of one primary cluster, and (if enabled) one or more replicas.
1. A subnet group that specifies which subnets to deploy the database nodes in.
1. A **Security Group** to limit access to the cluster.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.70.0/modules/data-stores/aurora) for more
information about the underlying Terraform module.
