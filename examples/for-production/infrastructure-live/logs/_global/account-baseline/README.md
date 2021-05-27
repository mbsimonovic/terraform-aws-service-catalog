# Account Baseline configuration for app accounts

This directory manages the account baseline configuration for app accounts (e.g. logs, shared-services, dev, stage, prod, etc) in a [Gruntwork Landing Zone](https://gruntwork.io/guides/foundations/how-to-configure-production-grade-aws-account-structure/) environment.


## Configurations for the logs account
The account baseline includes the following configurations:

- AWS Config is enabled in all regions and its logs are sent to an S3 bucket in the logs account.
- AWS CloudTrail is enabled in all regions and its logs are sent to an S3 bucket in the logs account.
- The [Autoscaling service-linked role](https://docs.aws.amazon.com/autoscaling/ec2/userguide/autoscaling-service-linked-role.html) is granted access to the AMI encryption key using KMS grants.
- A set of cross-account IAM roles is configured to allow access from the security account.
- An IAM password policy is configured.
- GuardDuty is configured with a detector in all regions.

Since this is the logs account, it is the central account that other accounts use for log aggregation. AWS services (such as CloudTrail and Config) running in other accounts send logs to S3 buckets in this account for the purposes of centralized observability, log integrity, auditability, and compliance.



For full details on what this configuration includes and how to use it, refer to the [`account-baseline-app` service catalog module](https://github.com/gruntwork-io/terraform-aws-service-catalog/blob/master/modules/landingzone/account-baseline-app/README.adoc). If you don't have access to this repo, email
[support@gruntwork.io](mailto:support@gruntwork.io).

See [the module docs](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/v0.36.1/modules/landingzone/account-baseline-app) for more
information about the underlying Terraform module.
