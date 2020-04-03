# Kubernetes Namespace Core Concepts

## How to configure Fargate

This module supports configuring a Namespace [Fargate
Profile](https://docs.aws.amazon.com/eks/latest/userguide/fargate-profile.html) so that all Pods in the Namespace run on
EKS Fargate. To create the Fargate profile, you must:

- Configure `kubernetes` provider to authenticate against EKS.
- Configure `aws` provider.
- Set `schedule_pods_on_fargate` to `true`.
- Provide Fargate configuration variables `eks_cluster_name`, `pod_execution_iam_role_arn`, and `worker_vpc_subnet_ids`.
  Note that the subnet IDs provided must be for private subnets of the VPC.

## How do you create multiple namespaces?

You will need to call this module multiple times to create multiple Namespaces. This means either having multiple
`module` blocks in Terraform, or multiple `terragrunt.hcl` configurations when using Terragrunt. Ideally this module can
support the creation and management of multiple Namespaces, but due to the limitations of Fargate Profile creation, it
is not ideal. Specifically:

- You can only create one Fargate Profile at a time. That is, when one is in the `CREATING` state, you can not create
  another one. This makes it hard to use Terraform looping constructs like `for_each` and `count`, which creates the
  resources in parallel.

- Alternatively, we can create a single Fargate Profile that matches multiple Namespaces. This is also not ideal because
  you can only have up to 5 selectors per Fargate Profile. This means that this approach will break down after 5
  Namespaces.

- Fargate Profiles are immutable, and require recreation everytime it is changed. In the second approach with selectors,
  this can cause service disruption as every Namespace change will cause Fargate Profiles to be recreated.
