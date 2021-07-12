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
