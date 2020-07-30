# ECS Cluster Module

This Terraform Module launches an [EC2 Container Service
Cluster](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_clusters.html) that you can use to run
Docker containers. The cluster consists of a configurable number of instances in an Auto Scaling Group (ASG). Each
instance:

1. Runs the [ECS Container Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) so
   it can communicate with the ECS scheduler.
1. Authenticates with a Docker repo so it can download private images. The Docker repo auth details should be encrypted
   using [Amazon Key Management Service (KMS)](https://aws.amazon.com/kms/) and passed in as input variables. The
   instances, when booting up, will use [gruntkms](https://github.com/gruntwork-io/gruntkms) to decrypt the data
   in-memory. Note that the IAM role for these instances, which uses `var.cluster_name` as its name, must be granted
   access to the [Customer Master Key
   (CMK)](http://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#master_keys) used to encrypt the data.
1. Runs the [CloudWatch Logs
   Agent](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/QuickStartEC2Instance.html) to send all
   logs in syslog to [CloudWatch
   Logs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/WhatIsCloudWatchLogs.html). This is
   configured using the [cloudwatch-log-aggregation-scripts
   module](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts).
1. Emits custom metrics that are not available by default in CloudWatch, including memory and disk usage. This is
   configured using the [cloudwatch-memory-disk-metrics-scripts
   module](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts).
1. Runs the [syslog module](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/syslog) to
   automatically rotate and rate limit syslog so that your instances don't run out of disk space from large volumes of
   logs.
1. Runs the [ssh-grunt module](https://github.com/gruntwork-io/module-security/tree/master/modules/ssh-grunt) so that
   developers can upload their public SSH keys to IAM and use those SSH keys, along with their IAM user names, to SSH
   to the ECS Nodes.
1. Runs the [auto-update module](https://github.com/gruntwork-io/module-security/tree/master/modules/auto-update) so
   that the ECS nodes install security updates automatically.





## How do you use this module?

1. Build the AMI
1. Deploy the Terraform code


### Build the AMI

Each EC2 instance in the ECS cluster should run an AMI built using the [Packer](https://www.packer.io/) template in
`ecs-node-al2.json`. To build the AMI:

1. Install [Packer](https://www.packer.io/).
1. Set your AWS credentials as the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
1. Set your [GitHub access token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/)
   as the environment variable `GITHUB_OAUTH_TOKEN`. Your GitHub account must have access to the Gruntwork GitHub
   repos mentioned in `ecs-node-al2.json`; if you don't have access to those, email support@gruntwork.io.
1. Run `packer build ecs-node-al2.json`.
1. When the build completes, it'll output the id of the new AMI.


### Deploy the Terraform code

* See the [root README](/README.md) for instructions on how to deploy the Terraform code in this repo.
* See [variables.tf](./variables.tf) for all the variables you can set on this module.





## How do you deploy updates to the cluster?

If you want to update the EC2 instances running in the ECS cluster (e.g. roll out a new AMI), you must use the
`roll-out-ecs-cluster-update.py` script in the Gruntwork
[ecs-module](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-cluster). Check out the
[How do you make changes to the EC2 Instances in the
cluster?](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-cluster#how-do-you-make-changes-to-the-ec2-instances-in-the-cluster)
documentation for details.





## What is an ECS Cluster?

To use ECS, you first deploy one or more EC2 Instances into a "cluster". The ECS scheduler can then deploy Docker
containers across any of the instances in this cluster. Each instance needs to have the [Amazon ECS
Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) installed so it can communicate with
ECS and register itself as part of the right cluster.

## Core concepts

For more info on ECS clusters, including how to run Docker containers in a cluster, how to add additional security
group rules, how to handle IAM policies, and more, check out the [ecs-cluster
documentation](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-cluster) in the
[module-ecs repo](https://github.com/gruntwork-io/module-ecs).

For info on finding your Docker container logs in CloudWatch, check out the [cloudwatch-log-aggregation-scripts
documentation](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/logs/cloudwatch-log-aggregation-scripts).
For info on viewing the custom metrics in CloudWatch, check out the [cloudwatch-memory-disk-metrics-scripts
documentation](https://github.com/gruntwork-io/module-aws-monitoring/tree/master/modules/metrics/cloudwatch-memory-disk-metrics-scripts).
