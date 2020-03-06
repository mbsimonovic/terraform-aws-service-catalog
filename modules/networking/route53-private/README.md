# Route53 Private Hosted Zones

This Terraform Module manages private DNS entries using [Amazon Route 53](https://aws.amazon.com/route53/).

For each domain name (e.g. example.com) you pass in, this module will create a [Route 53 Private Hosted
Zone](http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/AboutHZWorkingWith.html) in the VPC specified via the
`vpc_name` input variable. The Terraform configurations for each app are responsible for adding their individual DNS
records (e.g. foo.example.com) to this Hosted Zone.

## How do you use this module?

See the [root README](/README.md) for instructions on using modules.

## Core concepts

To understand core concepts like what is route 53, what is a public hosted zone, and more, see the [route 53
documentation](https://aws.amazon.com/documentation/route53/).
