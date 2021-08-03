# ElastiCache Redis Replication Group

This directory creates an [ElastiCache](http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/WhatIs.html)
Redis Replication Group. The resources that are created include:

1. The number of individual Redis nodes configured (each node is known as a **Cache Cluster** despite being a single
   node).
1. The **Replication Group** itself to allow for asynchronous replication.
1. A **Security Group** to limit access to the Replication Group.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.54.0/modules/data-stores/redis) for more
information about the underlying Terraform module.
