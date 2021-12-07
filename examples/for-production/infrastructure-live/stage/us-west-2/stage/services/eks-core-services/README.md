# EKS Core Services

This directory deploys core services on to the EKS cluster. The following core services are deployed by this module:

1. **Fluent Bit** to ship container logs to CloudWatch Logs.
1. **AWS LoadBalancer Controller** to configure ALBs and NLBs from within Kubernetes.
1. **External DNS**  to manage Route 53 DNS records from within Kubernetes.
1. **Kubernetes cluster-autoscaler** to configure auto scaling of ASGs based on Pod demand.

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.65.0/modules/services/eks-core-services) for more
information about the underlying Terraform module.
