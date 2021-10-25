## How do I perform a blue green release to roll out new versions of the module?

A [blue-green release](https://martinfowler.com/bliki/BlueGreenDeployment.html) is a deployment strategy where you
maintain two isolated copies of an environment, and you shift workload and traffic from the old environment ("blue") to
the new one ("green"). The idea is to have 0-downtime during the deployment by shifting traffic to a hot standby that is
already ready to serve traffic and workloads.

In the context of Kubernetes workers, a blue-green release would primarily be a way to deploy an isolated worker pool
that is not directly linked to the existing worker pool, and shift the Pods to the new one once it is deployed.

Compare this to [the standard way to roll out updates to worker pools using a rolling
release](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-cluster-workers#how-do-i-roll-out-an-update-to-the-instances),
where the existing worker pools are modified to provision new workers to transition traffic to. In the rolling release,
the existing Auto Scaling Groups are expanded. In a blue-green release, new Auto Scaling Groups are provisioned using
the new versions, without touching the existing ones. This leads to a safer deployment alternative as there is less risk
of inducing an accidental disruptive scale in as the existing ASGs are modified.

Gruntwork tries to provide migration paths that avoid downtime when rolling out new versions of the module. These are
usually implemented as feature flags, or a list of state migration calls that allow you to avoid a resource recreation.
However, it is not always possible to avoid a resource recreation with AutoScaling Groups or Managed Node Groups.

When it is not possible to avoid resource recreation, you can perform a blue-green release of the worker pool. In this
deployment model, you can deploy a new worker pool using the updated version, and migrate the Kubernetes workload to the
new cluster prior to spinning down the old one.

The following are the steps you can take to perform a blue-green release for this module:

- Add a new module block that calls the `eks-cluster-workers` using the new version, leaving the old module block with
  the old version untouched. For example, if you are going from `v0.64.0` to `v0.65.0`:
    - If you are using `terraform`:

          # If you are managing workers within the eks-cluster module
          module "cluster" {
            source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-cluster?ref=v0.64.0"
            # other args omitted for brevity
          }

          # If you are managing worker pools directly
          module "workers" {
            source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-workers?ref=v0.64.0"
            # other args omitted for brevity
          }

          module "next_version_workers" {
            source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/eks-workers?ref=v0.65.0"
            # other args omitted for brevity
          }

    - If you are using `terragrunt`, create a new folder for deploying a second worker pool by calling the `eks-workers`
      module. You can use a [dependency
      block](https://terragrunt.gruntwork.io/docs/features/execute-terraform-commands-on-multiple-modules-at-once/#passing-outputs-between-modules) to retrieve the EKS cluster information from the `eks-cluster` module output.

  This will spin up the new worker pool on the updated version in parallel with the old workers, without touching the
  old ones.

- Verify the new workers are up and available by using `kubectl get nodes`. Count the number of workers that are ready
  and make sure it matches what you expect from the two worker pools.

- Once the new workers are up, you can run `kubectl cordon` and `kubectl drain` on each instance in the old ASG to
  transition the workload over to the new worker pool. The `cordon` command prevents new workloads from being scheduled
  on the old ASG, while `drain` gracefully shuts down the Pods so that they can be migrated to the new nodes.
    - `kubergrunt` provides [a helper command](https://github.com/gruntwork-io/kubergrunt/#drain) to make it easier to run this:

          kubergrunt eks drain --asg-name my-asg-a --asg-name my-asg-b --asg-name my-asg-c --region us-east-2

  This command will cordon and drain all the nodes associated with the given ASGs.

- Once the workload is transitioned, you can tear down the old worker pool by dropping the old module block and running
  `terraform apply`. If you are using the `eks-cluster` module, you can set `autoscaling_group_configurations` or
  `node_group_configurations` to `null` to remove the old worker pool.



## IAM Roles and Kubernetes API Access

In order for the underlying `kubelet` process on the EC2 instances that are managed by this module to access the
Kubernetes API, the IAM role associated with the EC2 instance must be explicitly granted node level access in the
Kubernetes API. In EKS, this is managed through the `aws-auth` configuration, which maps IAM roles to
Kubernetes RBAC roles. You can read more about the `aws-auth` configuration in [the relevant section of
terraform-aws-eks
module](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-k8s-role-mapping#eks-k8s-role-mapping-module).

Below are instructions for two options on how to register the IAM role of the EC2 instances managed by this module in
the `aws-auth` configuration:

- [Option 1: Use the aws-auth-merger](#option-1-use-the-aws-auth-merger)
- [Option 2: Manually add the IAM role to `eks-cluster`
  module](#option-2-manually-add-the-iam-role-to-eks-cluster-module)


### Option 1: Use the aws-auth-merger

The [aws-auth-merger](https://github.com/gruntwork-io/terraform-aws-eks/tree/master/modules/eks-aws-auth-merger) is an
application that runs in your EKS cluster which watches for changes to `ConfigMaps` in a configured `Namespace` and
merge them together to construct the `aws-auth` configuration. This allows you to independently manage separate
`ConfigMaps` to append or remove permissions to the `aws-auth` configuration without having to centrally manage the
`ConfigMap`.

If the `aws-auth-merger` is deployed in your cluster, configure the `aws_auth_merger_namespace` input variable to the
Namespace that the `aws-auth-merger` is watching so that the module will create the `aws-auth` compatible `ConfigMap`
with the EKS worker IAM role to be merged into the main configuration.


### Option 2: Manually add the IAM role to eks-cluster module

If you do not have the `aws-auth-merger` deployed, then your only option is to update the central `aws-auth`
`ConfigMap` with the new IAM role that is created by this module. If you are using the [eks-cluster
module](../eks-cluster) to manage the EKS control plane, include the IAM role ARN of the worker pool in the
`worker_iam_role_arns_for_k8s_role_mapping` input variable.
