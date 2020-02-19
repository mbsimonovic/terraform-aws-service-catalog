# Mock ASG Service example

This is an example of how to use the [mock-asg-service module](/modules/mock-asg-service) to deploy a mock ASG in
AWS. This example is optimized for learning, experimenting, and testing (but not direct production usage). If you want
to deploy this module directly in production, check out the [examples/for-production folder](/examples/for-production).




## Deploy instructions

1. Install [Terraform](https://www.terraform.io/).
1. Configure your AWS credentials 
   ([instructions](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799)).
1. Run `terraform init`.   
1. Run `terraform apply`.  
1. When you're done testing, run `terraform destroy` to clean up. 