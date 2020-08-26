# Elasticsearch Cluster (VPC-based) Example

This is an example of how to use the [elasticsearch module](/modules/data-stores/elasticsearch) to create an [Amazon Elasticsearch cluster](https://aws.amazon.com/elasticsearch-service/). This example is optimized for learning, experimenting, and testing (but not direct production usage).
If you want to deploy this module directly in production, check out the [examples/for-production
folder](/examples/for-production).

This example deploys the Elasticsearch cluster to only be accessible from within a VPC. For a public cluster, see the [elasticsearch-public example](../elasticsearch-public).

You'll need to add a [Service-Linked Role for Elasticsearch](https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/slr-es.html) within your AWS account. The role is named `es.amazonaws.com`. You can create and manage it via the AWS Console UI.


## Deploy instructions

1. Install [Terraform](https://www.terraform.io/).
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any others you wish to override). We
   recommend setting these variables in a `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for all
   the ways you can set Terraform variables).
1. Run `terraform init`.
1. Run `terraform apply`.
1. The module will output the endpoint URL, ARN, and domain ID of the Elasticsearch cluster. It will also create a security group and output its ID.
1. When you're done testing, to undeploy everything, run `terraform destroy`.
