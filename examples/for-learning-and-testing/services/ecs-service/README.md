# ECS Service Example 

This is an example of how to use the [ecs-service
module](/modules/services/ecs-service) to create an ECS Service with a load
balancer and DNS records. 
This example is optimized for learning, experimenting, and testing (but not
direct production usage). 

Note that this ECS Service module requires the [ECS Cluster
module](/modules/services/ecs-cluster) to be
deployed first.  

### What is an ECS Cluster?

To use ECS, you first deploy one or more EC2 Instances into a "cluster". The ECS scheduler can then deploy Docker
containers across any of the instances in this cluster. Each instance needs to have the [Amazon ECS
Agent](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_agent.html) installed so it can communicate with
ECS and register itself as part of the right cluster.

### What is an ECS Service?

To run Docker containers with ECS, you first define an [ECS
Task](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_defintions.html), which is a JSON file that
describes what container(s) to run, the resources (memory, CPU) those containers need, the volumes to mount, the
environment variables to set, and so on. To actually run an ECS Task, you define an ECS Service, which can:

1. Deploy the requested number of Tasks across an ECS cluster based on the `desired_number_of_tasks` input variable.
1. Restart tasks if they fail.
1. Route traffic across the tasks with an optional Elastic Load Balancer (ELB). To use an ELB, set `is_associated_with_elb`
   to `true` and pass in the ELB details using the `elb_name`, `elb_container_name`, and `elb_container_port`
   input variables.

For more info on ECS services and clusters, check out the
[ecs-cluster](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-cluster) and
[ecs-service](https://github.com/gruntwork-io/module-ecs/tree/master/modules/ecs-service) documentation in the
[module-ecs repo](https://github.com/gruntwork-io/module-ecs).

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
