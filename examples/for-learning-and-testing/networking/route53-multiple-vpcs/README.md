# Route 53 Private Hosted Zone with Multiple VPCs Example

This is an example of how to use the [route53 module](/modules/networking/route53) to create a private hosted zone that
is associated with multiple VPCs. This example is optimized for learning, experimenting, and testing (but not direct
production usage). If you want to deploy this module directly in production, check out the [examples/for-production
folder](/examples/for-production).


### Deploy the VPC using Terraform

1. Install [Terraform](https://www.terraform.io/).
1. Configure your AWS credentials
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Open [variables.tf](variables.tf) and set all required parameters (plus any others you wish to override).
   We recommend setting these variables in a `terraform.tfvars` file (see
   [here](https://www.terraform.io/docs/configuration/variables.html#assigning-values-to-root-module-variables) for
   all the ways you can set Terraform variables).
1. Run `terraform init`.
1. Run `terraform apply`.
1. When you're done testing, to undeploy everything, run `terraform destroy`.