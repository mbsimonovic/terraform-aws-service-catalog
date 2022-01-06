# Core Concepts


1. [Setting up your AWS account structure ("Landing Zone")](#setting-up-your-aws-account-structure-landing-zone)
1. [Creating child accounts](#creating-child-accounts)
1. [Aggregating AWS Config and CloudTrail data in a logs account](#aggregating-aws-config-and-cloudtrail-data-in-a-logs-account)
1. [Why does this module use account-level AWS Config Rules?](#why-does-this-module-use-account-level-aws-config-rules)
1. [How to use multi-region services](#how-to-use-multi-region-services)

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
1. Run `terraform apply` (or `terragrunt apply` if you're using Terragrunt). 
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



## How to use multi-region services

Several of the services in this service catalog, including `account-baseline-root`, `account-baseline-security`, and
`account-baseline-app`, including multi-region modules (e.g., `aws-config-multi-region`, `guardduty-multi-region`, 
`ebs-encryption-multi-region`) which deploy resources across multiple AWS regions. In fact, the best practice for most
of these multi-region modules is to deploy them across _all_ the regions that are enabled in your AWS account. In
Terraform, each region requires creating a separate `provider` block, so using multi-region services requires that you
do the following:  
 
1. **Upgrade to at least Terraform 0.15.1.** The multi-region services use the `configuration_aliases` parameter in 
   Terraform, which is only available in versions 0.15.0 and above, and as you need the latest GPG keys 
   ([context](https://discuss.hashicorp.com/t/terraform-updates-for-hcsec-2021-12/23570)), you must use 0.15.1 or above. 
   Therefore, you must upgrade to at least Terraform 0.15.1 to use multi-region services. [Read our Terraform 0.15 
   migration guide here](https://gruntwork.io/guides/upgrades/how-to-update-to-terraform-15/).

1. **Instantiate a `provider` block for each AWS region.** In your Terraform or Terragrunt code, in the "root" module 
   (i.e., the one on which you run `apply`), you MUST instantiate one `provider` block for each AWS region. Don't 
   worry if you're not using all the regions or some are not enabled in your account: you'll configure `opt_in_regions` 
   shortly to only use the regions you want. However, you still have to create a `provider` block for every region, 
   whether you're using it or not. The easiest way to do this is to copy/paste one of the following:
    1. If you use Terragrunt, [copy/paste the `locals` and `generate` blocks](/examples/for-production/infrastructure-live/dev/_global/account-baseline/terragrunt.hcl) into your `terragrunt.hcl`. 
    1. If you use pure Terraform, [copy/paste this `providers.tf` into your module](/examples/for-learning-and-testing/landingzone/account-baseline-root/providers.tf). 

1. **Pass in a `providers` map.** You must pass a `providers = { ... }` map to the multi-region module that contains 
   all of your `provider` blocks, as shown in the example below. Note that this is only necessary if you're using pure 
   Terraform; Terragrunt users can skip this step.

    ```hcl
    module "aws_config" {
      source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/account-baseline-root?ref=v0.52.0"     

      # You MUST create a provider block for EVERY AWS region (see providers.tf) and pass all those providers in here via
      # this providers map. However, you should use var.opt_in_regions to tell Terraform to only use and authenticate to
      # regions that are enabled in your AWS account.
      providers = {
        aws                = aws.default
        aws.af_south_1     = aws.af_south_1
        aws.ap_east_1      = aws.ap_east_1
        aws.ap_northeast_1 = aws.ap_northeast_1
        aws.ap_northeast_2 = aws.ap_northeast_2
        aws.ap_northeast_3 = aws.ap_northeast_3
        aws.ap_south_1     = aws.ap_south_1
        aws.ap_southeast_1 = aws.ap_southeast_1
        aws.ap_southeast_2 = aws.ap_southeast_2
        aws.ap_southeast_3 = aws.ap_southeast_3
        aws.ca_central_1   = aws.ca_central_1
        aws.cn_north_1     = aws.cn_north_1
        aws.cn_northwest_1 = aws.cn_northwest_1
        aws.eu_central_1   = aws.eu_central_1
        aws.eu_north_1     = aws.eu_north_1
        aws.eu_south_1     = aws.eu_south_1
        aws.eu_west_1      = aws.eu_west_1
        aws.eu_west_2      = aws.eu_west_2
        aws.eu_west_3      = aws.eu_west_3
        aws.me_south_1     = aws.me_south_1
        aws.sa_east_1      = aws.sa_east_1
        aws.us_east_1      = aws.us_east_1
        aws.us_east_2      = aws.us_east_2
        aws.us_gov_east_1  = aws.us_gov_east_1
        aws.us_gov_west_1  = aws.us_gov_west_1
        aws.us_west_1      = aws.us_west_1
        aws.us_west_2      = aws.us_west_2
      }

      # ... (other params omitted) ...

    }  
    ```

1. **Configure the regions to use via `opt_in_regions`.** You MUST set the `xxx_opt_in_regions` variables (e.g., 
   `config_opt_in_regions`, `guardduty_opt_in_regions`, `ebs_opt_in_regions`, etc.) to the list of regions you wish to 
   use in your AWS account. This will typically be all the enabled regions in your account. You cannot leave the 
   variable as `null` or empty. To get the list of regions enabled in your AWS account, you can use the AWS CLI: 
   `aws ec2 describe-regions`.

    ```hcl
    variable "opt_in_regions" {
      description = "Create multi-region resources in the specified regions. The best practice is to enable multi-region services in all enabled regions in your AWS account. This variable must NOT be set to null or empty. Otherwise, we won't know which regions to use and authenticate to, and may use some not enabled in your AWS account (e.g., GovCloud, China, etc).  To get the list of regions enabled in your AWS account, you can use the AWS CLI: aws ec2 describe-regions. The value provided for global_recorder_region must be in this list."
      type        = list(string)
      default = [
        "eu-north-1",
        "ap-south-1",
        "eu-west-3",
        "eu-west-2",
        "eu-west-1",
        "ap-northeast-2",
        "ap-northeast-1",
        "sa-east-1",
        "ca-central-1",
        "ap-southeast-1",
        "ap-southeast-2",
        "eu-central-1",
        "us-east-1",
        "us-east-2",
        "us-west-1",
        "us-west-2",

        # By default, skip regions that are not enabled in most AWS accounts:
        #
        #  "af-south-1",     # Cape Town
        #  "ap-east-1",      # Hong Kong
        #  "eu-south-1",     # Milan
        #  "me-south-1",     # Bahrain
        #  "us-gov-east-1",  # GovCloud
        #  "us-gov-west-1",  # GovCloud
        #  "cn-north-1",     # China
        #  "cn-northwest-1", # China
        #
        # This region is enabled by default but is brand-new and some services like AWS Config don't work.
        # "ap-northeast-3", # Asia Pacific (Osaka)
      ]
    }
    ```
1. **Set other input variables as usual**. Browse `variables.tf` for the module and configure it to fit your use case.

1. **Run `plan` and `apply` as usual**. Run the standard Terraform commands you use to deploy any other module.
      
