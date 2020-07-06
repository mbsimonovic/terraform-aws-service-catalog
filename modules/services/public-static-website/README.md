# Static Website Module

This Terraform Module deploys a static website in an [S3 Bucket](https://aws.amazon.com/s3/) and a [CloudFront](https://aws.amazon.com/cloudfront/) distribution in front of it as a CDN.

## How do you use this module?

* See the [root README](/README.md) for instructions on using Terraform modules.
* See [variables.tf](./variables.tf) for all the variables you can set on this module.

## Core concepts

For more info on why you would use S3 to store static content, why you may want a CDN in front of it, how to access the 
website, and how to configure SSL, check out the documentation for the 
[s3-static-website](https://github.com/gruntwork-io/package-static-assets/tree/master/modules/s3-static-website) and
[s3-cloudfront](https://github.com/gruntwork-io/package-static-assets/tree/master/modules/s3-cloudfront) modules.
