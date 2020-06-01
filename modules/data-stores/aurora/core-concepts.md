# Aurora Core Concepts

## How to backup Aurora snapshots to a separate AWS Account?

RDS comes with nightly snapshots by default, but does not support cross account sharing of those snapshots. This module
supports automatically setting up backups that can be shared and stored in a separate AWS account.

To configure cross account snapshots, set the following input variables:

- Set `share_snapshot_with_another_account` to `true`
- Provide the target account to backup snapshots into using `share_snapshot_with_account_id`
- Provide a schedule for taking snaphots using `share_snapshot_schedule_expression`
- Optionally enable alarms for snapshot failures by setting `enable_share_snapshot_cloudwatch_alarms` to `true`

Under the hood these actions deploy three AWS Lambda functions that will run on the provided schedule to:

- Manually create a new RDS snapshot that should be shared with another account.
- Expose the manual RDS snapshot to make it visible to the target account.
- Clean up old snapshots, saving up to a maximum of the number provided with `share_snapshots_max_snapshots`.

**IMPORTANT**: This only makes the snapshot _visible_ to the target account, but does not actually copy it into the
other account. You will need to deploy the [lambda-copy-shared-snapshot module](../lambda-copy-shared-snapshot) in the
target account to accomplish this task.


## How do I deploy Aurora Serverless?

To use Aurora Serverless with this module, you need to set the `engine_mode` to `serverless`.


## How do I scale the Aurora Serverless Database?

Aurora Serverless does not have any server based configurations. Instead, the capacity is managed with a single unit
called Aurora capacity units. You can configure minimum and maximum values for the ACU and AWS will dynamically scale
the cluster based on demand.

You can set the ACU capacity using the `scaling_configuration_min_capacity` and `scaling_configuration_max_capacity`
input values.

To learn more about what settings you should set, take a look at the blog post [Aurora Serverless: The Good, Bad, and
the Ugly](https://www.jeremydaly.com/aurora-serverless-the-good-the-bad-and-the-scalable/).


## How do I use Kubernetes Service Discovery with the Aurora Database?

You can register the RDS database endpoint to the internal DNS service used by Kubernetes by creating a Kubernetes
[Service resource](https://kubernetes.io/docs/concepts/services-networking/service/) of type
[ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname) that can be used to route
requests against that Service to the primary endpoint of the Aurora database. We recommend using the Service DNS Mapping
feature of the [eks-core-services module](../../services/eks-core-services) to bind the primary endpoint of the Aurora
database to a Kubernetes Service. See the [relevant
documentation](../../services/eks-core-services/core-concepts.md#how-do-i-register-external-services-to-internal-dns)
for more information.
