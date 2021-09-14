## How do you configure cluster autoscaling?

ECS Clusters support two tiers of autoscaling:

- Autoscaling of ECS Service and Tasks, where ECS will horizontally or vertically scale your ECS Tasks by provisioning
  more replicas of the Task or replacing them with Tasks that have more resources allocated to it.
- Autoscaling of the ECS Cluster, where the AWS Autoscaling Group will horizontally scale the worker nodes by
  provisioning more.

The `ecs-cluster` module supports configuring ECS Cluster Autoscaling by leveraging [ECS Capacity
Providers](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-capacity-providers.html). You can read
more about how cluster autoscaling works with capacity providers in the [official
documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cluster-auto-scaling.html).

To enable capacity providers for cluster autoscaling on your ECS cluster, you will want to configure the following
variables:

```hcl
# Turn on capacity providers for autoscaling
capacity_provider_enabled = true

# Enable Multi AZ capacity providers to balance autoscaling load across AZs. This should be true in production. Can be
# false in dev and stage.
multi_az_capacity_provider = true

# Configure target utilization for the ECS cluster. This number influences when scale out happens, and when instances
# should be scaled in. For example, a setting of 90 means that new instances will be provisioned when all instances are
# at 90% utilization, while instances that are only 10% utilized (CPU and Memory usage from tasks = 10%) will be scaled
# in. A recommended default to start with is 90.
capacity_provider_target = 90

# The following are optional configurations, and configures how many instances should be scaled out or scaled in at one
# time. Defaults to 1.
# capacity_provider_max_scale_step = 1
# capacity_provider_min_scale_step = 1
```

### Note on toggling capacity providers on existing ECS Clusters

Each EC2 instance must be registered with Capacity Providers to be considered in the pool. This means that when you
enable Capacity Providers on an existing ECS cluster that did not have Capacity Providers, you must rotate the EC2
instances to ensure all the instances get associated with the new Capacity Provider.

To rotate the instances, you can run the
[roll-out-ecs-cluster-update.py](https://github.com/gruntwork-io/terraform-aws-ecs/blob/master/modules/ecs-cluster/roll-out-ecs-cluster-update.py)
script in the `terraform-aws-ecs` module. Refer to the
[documentation](https://github.com/gruntwork-io/terraform-aws-ecs/tree/master/modules/ecs-cluster#how-do-you-make-changes-to-the-ec2-instances-in-the-cluster)
for more information on the script.
