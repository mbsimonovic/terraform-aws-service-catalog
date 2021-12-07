# Public Facing ALB

This directory creates an external, public facing [Application Load
Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html).

Under the hood, this is all implemented using Terraform modules from the [Gruntwork Service
Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog) repo. If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.65.0/modules/networking/alb) for more
information about the underlying Terraform module.
