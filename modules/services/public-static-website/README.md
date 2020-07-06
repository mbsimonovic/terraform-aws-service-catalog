# Public Static Website Module

This Terraform Module deploys a public static website in an [S3 Bucket](https://aws.amazon.com/s3/) with a [CloudFront](https://aws.amazon.com/cloudfront/) distribution in front of it as a CDN.

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See [variables.tf](./variables.tf) for all the variables you can set on this module.

## Core concepts

This module deploys a public website, so the S3 bucket and objects with it are readable by the public. It also is hosted in a Public Hosted Zone in Route 53. You may provide a `hosted_zone_id` in [variables](./variables.tf), or you may provide the `base_domain_name` associated with your Public Hosted Zone in Route 53, optionally along with any tags that must match that zone in `base_domain_name_tags`. If you do the latter, this module will find the hosted zone id for you.

For more info on why you would use S3 to store static content, why you may want a CDN in front of it, how to access the
website, and how to configure SSL, check out the documentation for the
[s3-static-website](https://github.com/gruntwork-io/package-static-assets/tree/master/modules/s3-static-website) and
[s3-cloudfront](https://github.com/gruntwork-io/package-static-assets/tree/master/modules/s3-cloudfront) modules.
