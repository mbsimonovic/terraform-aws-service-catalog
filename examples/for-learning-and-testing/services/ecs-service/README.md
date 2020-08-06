# ECS Service Example 

This is an example of how to use the [ecs-service
module](/modules/services/ecs-service) to create an ECS Service with a load
balancer and DNS records. 
This example is optimized for learning, experimenting, and testing (but not
direct production usage). 

Note that this ECS Service module requires the [ECS Cluster
module](/modules/services/ecs-cluster) to be
deployed first.  

### Deploy the ECS Cluster using Terraform 

Before attempting to deploy the ECS Service module, follow the guide in the
[ECS Cluster module](/modules/services/ecs-cluster) to deploy the cluster
first. 

Once the ECS cluster is successfully deployed, the module will output the ECS
Service ARN, which you can input to the ECS Service module via the
`ecs_cluster_arn` variable in order to deploy
the service onto the cluster.

### Deploy the ECS Service using Terraform 

1. Install [Terraform](https://www.terraform.io)
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any others you wish to override).
   We recommend setting these variables in a `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for
   all the ways you can set Terraform variables).
1. Run `terraform init`.
1. Run `terraform apply`.
1. When you're done testing, to undeploy everything, run `terraform destroy`.
