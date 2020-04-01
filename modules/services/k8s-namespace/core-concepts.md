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
