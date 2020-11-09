# S3 Bucket Example

This is an example of how to use the [S3 Bucket module](/modules/data-stores/s3-bucket) to deploy an Amazon S3 bucket. 
The bucket deployed in this example is private (all public access is blocked), secure (all access is over TLS) and 
has access logging to another S3 bucket as well as versioning enabled.
 
This example is optimized for learning, experimenting, and testing (but not direct production usage).
If you want to deploy this module directly in production, check out the [examples/for-production
folder](/examples/for-production).




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
1. The module will output the name and the ARN for your S3 bucket.
1. When you're done testing, to undeploy everything, run `terraform destroy`.
