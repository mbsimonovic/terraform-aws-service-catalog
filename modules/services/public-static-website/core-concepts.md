
## Quick Start

* Check out the [production example code](/examples/for-learning-and-testing/services/public-static-website/example-website).
* Check out [variables.tf](/modules/services/public-static-website/variables.tf) for parameters you can set for this service module.
* In the underlying module repo, see the [s3-static-website example](https://github.com/gruntwork-io/terraform-aws-static-assets/tree/master/examples/s3-static-website) for sample code.
* In the underlying module repo, check out [vars.tf](https://github.com/gruntwork-io/terraform-aws-static-assets/blob/master/modules/s3-static-website/vars.tf) for all parameters you can set for the underlying module.

## How to configure HTTPS (SSL) or a CDN?

This is configured by default. This module deploys a CloudFront distribution
in front of the S3 bucket to allow the static content to be accessible over HTTPS. This also acts as a Content Distribution
Network (CDN), which reduces latency for your users.
