# Core Concepts


1. [Setting up your AWS account structure ("Landing Zone")](#setting-up-your-aws-account-structure-landing-zone)
1. [Creating child accounts](#creating-child-accounts)
1. [Aggregating AWS Config and CloudTrail data in a logs account](#aggregating-aws-config-and-cloudtrail-data-in-a-logs-account)
1. [Why does this module use account-level AWS Config Rules?](#why-does-this-module-use-account-level-aws-config-rules)


## Setting up your AWS account structure ("Landing Zone")

For a detailed, step-by-step guide of how to set up your AWS account structure, see [How to configure a 
production-grade AWS account structure using Gruntwork AWS Landing Zone](https://gruntwork.io/guides/foundations/how-to-configure-production-grade-aws-account-structure/). 




## Creating child accounts

Here's a rough overview of how to create child accounts using this module:

1. Specify the child accounts you want to create using the `child_accounts` variable:

    ```hcl
    module "root_account_baseline" {
      # Replace <VERSION> in the URL below with the latest release from terraform-aws-security
      source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/account-baseline-root?ref=<VERSION>"
      
      # If you're running the example against an account that doesn't have AWS Organization already created, change the 
      # following value to true
      create_organization = false

      # Configure the child accounts to create
      child_accounts = {
        # A logs account for aggregating AWS Config and CloudTrail data from all accounts
        logs = {
          email                       = "root-accounts+logs@acme.com"
          is_logs_account             = true
        }
        # A security account where all IAM users / groups are defined
        security = {
          email                       = "root-accounts+security@acme.com"
          role_name                   = "OrganizationAccountAccessRole"
          iam_user_access_to_billing  = "DENY"
          tags = {
            Tag-Key = "tag-value"
          }
        }
        # A shared-services account for tooling shared across all accounts, such as Jenkins, AMIs, ECR repos
        shared-services = {
          email                       = "root-accounts+shared-services@acme.com"
        }
        # Dev environment
        dev = {
          email                       = "root-accounts+dev@acme.com"
        }
        # Staging environment
        stage = {
          email                       = "root-accounts+stage@acme.com"
        }
        # Production environment
        prod = {
          email                       = "root-accounts+prod@acme.com"
        }
      }
      
      # Configure AWS Config and CloudTrail S3 buckets and KMS CMKs, all of which will be created in the logs account
      config_s3_bucket_name                     = "<CONFIG_S3_BUCKET_NAME>"
      cloudtrail_s3_bucket_name                 = "<CLOUDTRAIL_S3_BUCKET_NAME>"
      cloudtrail_kms_key_administrator_iam_arns = ["arn:aws:iam::<ROOT_ACCOUNT_ID>:user/<YOUR_IAM_USER_ID>"]
   
      # ... other params omitted ...
    }
    ```

    The key in the `child_accounts` map is a name for the account (e.g., dev, stage, prod) and the value is an object that
    configures the account. The most important parameters to set in that object are:
    
    * `email` (required): This will be the email address for the root user of the account. AWS requires that the root user 
      email is globally unique, so you cannot re-use the same email address for multiple accounts.
      
    * `is_logs_account`: We strongly recommend setting this variable to `true` on exactly one of your child accounts to 
      mark it as the "logs" account, which is meant to be used for aggregating all audit logs. See [Aggregating AWS 
      Config and CloudTrail data in a logs account](#aggregating-aws-config-and-cloudtrail-data-in-a-logs-account) for 
      more info.
      
    See [`variables.tf`](variables.tf) for the full list of parameters.    

1. Authenticate as an *IAM User* to the root account in your AWS organization. You cannot use the root user, as the
   `account-baseline-root` module needs to assume an IAM role, which is something a root user cannot do. Therefore, you
   MUST use an IAM user.  
1. Run `ulimit -n 1024`. This is necessary on some operating systems (especially MacOS) to increase the file limit so 
   you don't get `Error: pipe: too many open files` errors.
1. Run `terraform apply -parallelism=2` (or `terragrunt apply -parallelism=2` if you're using Terragrunt). We recommend 
   using a `-parallelism` flag with a low value for stable performance as this module can peg all of your CPU cores and 
   cause timeout/network connectivity errors.
1. Once the child accounts have been created, authenticate to each one, and apply a baseline to it using either the 
   [account-baseline-security module](/modules/account-baseline-security) (for the security account) or the
   [account-baseline-app module](/modules/account-baseline-app) (for all other account types).
   
See [How to configure a 
production-grade AWS account structure using Gruntwork AWS Landing Zone](https://gruntwork.io/guides/foundations/how-to-configure-production-grade-aws-account-structure/)
for the full, step-by-step details.  




## Aggregating AWS Config and CloudTrail data in a logs account
   
We recommend using a multi-account structure where you run different types of environments, workloads, and teams in
separate AWS accounts (see [How to configure a production-grade AWS account structure using Gruntwork AWS Landing 
Zone](https://gruntwork.io/guides/foundations/how-to-configure-production-grade-aws-account-structure/) for more 
context). One of the accounts in this multi-account structure should be a _logs account_ which is used to aggregate
log data from tools such as AWS Config and CloudTrail. There's a bit of a chicken-and-egg situation with the logs 
account, as you want to have all accounts, including root, send log data to it, but the very fist time you run `apply`,
the account and the resources it needs to store that data—the S3 buckets and KMS CMKs—don't exist yet.  

This module can solve that problem for you by automatically creating the S3 buckets and KMS CMKs in one of the child
accounts. To tell it which child account, set `is_logs_account = true` on exactly one of the child accounts in the
`child_accounts` input variables:

```hcl
module "root_account_baseline" {
  # Replace <VERSION> in the URL below with the latest release from terraform-aws-security
  source = "git::git@github.com:gruntwork-io/terraform-aws-security.git//modules/account-baseline-root?ref=<VERSION>"
  
  child_accounts = {
    logs = {
      email                       = "root-accounts+logs@acme.com"
      is_logs_account             = true
    }
  }
  
  # ... other params omitted ...
}
```

When this module finds a child account with `is_logs_account` set to `true`, it will:

1. Create the child account.
1. Authenticate to it.
1. Create an S3 bucket in the child account for AWS Config data.  
1. Create an S3 bucket and KMS CMK in the child account for CloudTrail data.
1. Configure the root account to send all its AWS Config and CloudTrail data to this child account.
1. Give you the S3 and KMS CMK details as output variables.

When applying account baselines to all your other child accounts, we recommend configuring them to use the exact same
S3 buckets and KMS CMK so all the AWS Config and CloudTrail data ends up in the same account.

_Note: Having the root account authenticate to and create resources in a child account is a slightly odd practice, as
that means some of the resources in that account and the Terraform state for them live in a different account. This is
not the ideal design, but it's necessary to solve the chicken-and-egg problem described in the intro paragraph!_  




## Why does this module use account-level AWS Config Rules?

This module configures account-level rather than organization-level AWS Config Rules. See [How do Organization-Level 
Config Rules Compare to Account-Level Config Rules?](/modules/aws-config-rules/core-concepts.md#how-do-organization-level-config-rules-compare-to-account-level-config-rules)
for an explanation of why and the security implications.      