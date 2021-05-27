# Public Route53 Hosted Zone

This directory manages an external, public facing [Route53
Hosted Zone](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html).

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.36.1/modules/networking/route53) for more
information about the underlying Terraform module.
