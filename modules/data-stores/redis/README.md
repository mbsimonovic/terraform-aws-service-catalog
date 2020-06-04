# ElastiCache Redis Replication Group

This directory creates an an [ElastiCache](http://docs.aws.amazon.com/AmazonElastiCache/latest/UserGuide/WhatIs.html)
Redis Replication Group. The resources that are created include:

1. The number of individual Redis nodes configured (each node is known as a **Cache Cluster** despite being a single
   node).
1. The **Replication Group** itself to allow for asynchronous replication.
1. A **Security Group** to limit access to the Replication Group.

Under the hood, this is all implemented using Terraform modules from the Gruntwork
[module-cache](https://github.com/gruntwork-io/module-cache) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).




## How do you use this module?

See the [root README](/README.md) for instructions on using modules.





## Known errors

When you run `terraform apply` on these templates the first time, you may see the following error:

```
* aws_security_group.redis: diffs didn't match during apply. This is a bug with Terraform and should be reported as a GitHub Issue.
```

As the error implies, this is a Terraform bug, but fortunately, it's a harmless one related to the fact that AWS is
eventually consistent, and Terraform occasionally tries to use a recently-created resource that isn't yet available.
Just re-run `terraform apply` and the error should go away.




## Core concepts

To understand core concepts like what is ElastiCache, how to connect, how to use clustering, and more, see the module
documentation for [redis](https://github.com/gruntwork-io/module-cache/tree/master/modules/redis).
