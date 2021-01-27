# ECS cluster Example 

This is an example of how to use the [ecs-cluster
module](/modules/clusters/ecs-cluster) to create an ECS cluster backed by EC2
instances. 
This example is optimized for learning, experimenting, and testing (but not
direct production usage). 

### Build the AMI

Each EC2 instance in the ECS cluster should run an AMI built using the [Packer](https://www.packer.io/) template in
`ecs-node-al2.json`. To build the AMI:

1. Install [Packer](https://www.packer.io/).
1. Set your AWS credentials as the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
1. Set your [GitHub access token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/) as the environment variable `GITHUB_OAUTH_TOKEN`. Your GitHub account must have access to the Gruntwork GitHub
   repos mentioned in `ecs-node-al2.json`; if you don't have access to those, email support@gruntwork.io.
1. Run `packer build ecs-node-al2.json`.
1. When the build completes, it'll output the id of the new AMI.


### Deploy the ECS cluster using Terraform 

1. Install [Terraform](https://www.terraform.io)
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any others you wish to override).
   We recommend setting these variables in a `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for all the ways you can set Terraform variables).
1. Run `terraform init`.
1. Run `terraform apply`.
1. Once the ECS cluster is successfully deployed, the module will output the ECS
cluster ARN, via the `ecs_cluster_arn` output, which you can input to the ECS service module via the
`ecs_cluster_arn` variable in order to deploy
the service onto the cluster.
1. When you're done testing, to undeploy everything, run `terraform destroy`.

### How do you deploy updates to the cluster?

If you want to update the EC2 instances running in the ECS cluster (e.g. roll out a new AMI), you must use the
`roll-out-ecs-cluster-update.py` script in the Gruntwork
[ecs-module](https://github.com/gruntwork-io/terraform-aws-ecs/tree/master/modules/ecs-cluster). Check out the
[How do you make changes to the EC2 Instances in the
cluster?](https://github.com/gruntwork-io/terraform-aws-ecs/tree/master/modules/ecs-cluster#how-do-you-make-changes-to-the-ec2-instances-in-the-cluster)
documentation for details.



