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

## How do you enable MFA Delete?

Enabling MFA Delete in your bucket adds another layer of security by requiring MFA in any request to delete a version or change the versioning state of the bucket.

The attribute `mfa_delete` is only used by Terraform to [reflect the current state of the bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket#mfa_delete). It is not possible to create a bucket if the `mfa_delete` is `true`, because it needs to be activated [using AWS CLI or the API](https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiFactorAuthenticationDelete.html).

To make this change [**you need to use the root user of the account**](https://docs.aws.amazon.com/general/latest/gr/root-vs-iam.html#aws_tasks-that-require-root) that owns the bucket, and MFA needs to be enabled.

**Note:** We do not recommend you to have access keys for the root user, so remember to delete them after you finish this.

In order to enable MFA Delete, you need to:
1. Create a bucket with `mfa_delete=false`.
1. [Create access keys for the root user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html#id_root-user_manage_add-key)
1. [Configure MFA for the root user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html#id_root-user_manage_mfa)
1. Using the root user, call the AWS CLI to enable MFA Delete. If you are using `aws-vault`, it is necessary to use the `--no-session` flag.
    ```
    aws s3api put-bucket-versioning --region <REGION> --bucket <BUCKET NAME> --versioning-configuration Status=Enabled,MFADelete=Enabled --mfa "arn:aws:iam::<ACCOUNT ID>:mfa/root-account-mfa-device <MFA CODE>"
    ```
1. Set `enable_versioning=true`
1. Set `mfa_delete=true`
1. Remove any Lifecycle Rule that the bucket might contain (the default is `{}`, in the AWS Config and Cloudtrail modules, you need to set `s3_enable_lifecycle_rules=false`).
1. Run `terraform apply`.
1. If there are no left S3 buckets to enable MFA Delete, delete the access keys for the root user, but NOT the MFA.
