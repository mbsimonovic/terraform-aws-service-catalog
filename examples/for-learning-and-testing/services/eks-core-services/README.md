# EKS Core Services Example

This is an example of how to use the [eks-core-services module](/modules/services/eks-core-services) to deploy core
administrative services on to an EKS cluster. See the [eks-cluster example](../eks-cluster) for an example of how to
deploy an EKS cluster.

This example is optimized for learning, experimenting, and testing (but not direct production usage). If you want
to deploy this module directly in production, check out the [examples/for-production folder](/examples/for-production).


## Deploy the core services using Terraform

### Pre-requisites

This example assumes that you already have a running EKS cluster. Use the [eks-cluster example](../eks-cluster) to
deploy one if you do not have one already.

### Deploy

1. Install [Terraform](https://www.terraform.io/).
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any others you wish to override).
   We recommend setting these variables in a `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for
   all the ways you can set Terraform variables).
1. Fill in the `eks_cluster_name`, `vpc_id`, and `eks_iam_role_for_service_accounts_config` variables from the outputs
   of the `eks-cluster` module.
1. Run `terraform init`.
1. Run `terraform apply`.
1. When you're done testing, to undeploy everything, run `terraform destroy`.
