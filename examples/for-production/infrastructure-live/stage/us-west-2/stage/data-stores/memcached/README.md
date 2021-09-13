# ElastiCache Memcached Cluster

This directory creates an [ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/WhatIs.html)
Memcached Cluster. The resources that are created include:

1. The ElastiCache memcached cluster, comprising one or more nodes running memcached
1. A subnet group that specifies which subnets to deploy the cache nodes in
1. A **Security Group** to limit access to the cluster.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.60.1/modules/data-stores/memcached) for more
information about the underlying Terraform module.
