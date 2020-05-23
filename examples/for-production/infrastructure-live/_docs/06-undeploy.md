# Undeploying the Reference Architecture

In the previous section, you learned how to check [metrics, logs, and alerts](05-monitoring-alerting-logging.md). In
this section, we'll walk you through how to undeploy parts or all of the Reference Architecture. 

1. [Before you get started](#before-you-get-started)
1. [Pre-requisite: force_destroy on S3 buckets](#pre-requisite-force_destroy-on-S3-buckets)
1. [Pre-requisite: disable Terragrunt prevent_destroy](#pre-requisite-disable-terragrunt-prevent_destroy)
1. [Pre-requisite: understand module dependencies](#pre-requisite-understand-module-dependencies)
1. [Undeploying a single module](#undeploying-a-single-module)
1. [Undeploying multiple modules or an entire environment](#undeploying-multiple-modules-or-an-entire-environment)
1. [Removing the terraform state](#removing-the-terraform-state)
1. [Known errors](#known-errors)
1. [Next steps](#next-steps)




## Before you get started

Terraform makes it fairly easy to delete resources using the `destroy` command. This is very useful in testing and 
pre-prod environments, but can also be dangerous in production environments, because if you delete resources, **there 
is no undo**. Therefore, be extra sure and careful with where you run `destroy` so you don't accidentally end up 
deleting something you'll very much regret (e.g., a production database). Also, as explained in the rest of this guide,
we put a few features in place that make deletion harder (read: a bit more annoying to do) to prevent you from 
accidentally shooting yourself in the foot. 




## Pre-requisite: force_destroy on S3 buckets

By default, if your Terraform code includes an S3 bucket, when you run `terraform destroy`, if that bucket contains
any content, Terraform will _not_ delete the bucket and instead will give you an error like this:

```
bucketNotEmpty: The bucket you tried to delete is not empty. You must delete all versions in the bucket.
```

This is a safety mechanism to ensure that you don't accidentally delete your data. 

*If you are absolutely sure you want to delete the contents of an S3 bucket* (remember, there's no undo!!!), all the 
services that use S3 buckets expose a `force_destroy` setting that you can set to `true` in your `terragrunt.hcl` 
files to tell that service to delete the contents of the bucket when you run `destroy`. Here's a partial list of 
services that expose this variable (note, you may not have all of these in your Reference Architecture!):

* `networking/alb`
* `mgmt/openvpn-server`
* `landingzone/account-baseline-security`
* `services/k8s-service`




## Pre-requisite: disable Terragrunt prevent_destroy

Terragrunt supports a [prevent_destroy](https://github.com/gruntwork-io/terragrunt#prevent_destroy) flag that you can
set to `true` in your `terragrunt.hcl` to protect valuable resources from accidental deletion (e.g., your database
and VPC). By default, we have `prevent_destroy` set on a few modules in the prod environment (namely, the production 
data stores and VPCs). If you run `terragrunt destroy` on a module with this setting, Terragrunt will simply log a 
warning and exit without deleting anything. 

*If you are absolutely sure you want to run destroy on this module* (remember, there's no undo!), you'll need to 
set `prevent_destroy = false` in the corresponding `terragrunt.hcl` file. 

**Important exception**: for multi-account deployments, we set `prevent_destroy = true` on the `iam-cross-account` 
module. This module creates the IAM Roles you use to authenticate to an AWS account, so you should **NOT** set
`prevent_destroy = false` on this module and do **NOT** run `destroy` on it, or you'll be locked out of the account!  




## Pre-requisite: understand module dependencies

Important note: some of your Terraform modules may depend on other ones! For example, most modules depend on the `vpc` 
module, fetching information about the VPC using  [Terragrunt `dependency` 
blocks](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#dependency) or 
[aws_vpc](https://www.terraform.io/docs/providers/aws/d/vpc.html) data source. If you run `destroy` on your `vpc` 
*before* the modules that depend on it, then any command you try to run on those other modules will fail, as their
data sources will no longer be able to fetch the VPC info!

Therefore, you should only destroy a module if you're sure no other module depends on it! Terraform does not provide
an easy way to track these sorts of dependencies. Your best bet is to manually track your dependencies using the
[`dependency`](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#dependency) and
[`dependencies`](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#dependencies) features of 
Terragrunt and to only undeploy modules that don't appear in the `dependencies` list of any other deployed module.




## Undeploying a single module

Now that all the pre-requisites are out of the way, *if you are absolutely sure you want to run destroy on a single 
module* (remember, there's no undo!), just go into that module's folder and run `terragrunt destroy`. For example, to
undeploy the sample-app-frontend service in the `stage` environment, you'd run:

```
cd stage/eu-west-1/stage/services/sample-app-frontend
terragrunt destroy
```




## Undeploying multiple modules or an entire environment

*If you are absolutely sure you want to run destroy on multiple modules or an entire environment* (remember, there's
no undo!), you can use the `destroy-all` command. For example, to undeploy the entire staging environment, you'd run:

```
cd stage
terragrunt destroy-all
```

Terragrunt will then run `terragrunt destroy` in each subfolder of the current working directory, processing them in
reverse order based on the dependencies you define in the `terragrunt.hcl` files. 

To avoid interactive prompts from Terragrunt (use very carefully!!), add the `--terragrunt-non-interactive` flag:

```
cd stage
terragrunt destroy-all --terragrunt-non-interactive
```

To undeploy everything except a couple specific subfolders, add the `--terragrunt-exclude-dir` flag. For example, to
run `destroy` in each subfolder of the `stage` environment except MySQL and Redis, you'd run:

```
cd stage
terragrunt destroy-all \
    --terragrunt-exclude-dir stage/us-east-1/stage/data-stores/mysql \ 
    --terragrunt-exclude-dir stage/us-east-1/stage/data-stores/redis 
```



## Removing the terraform state

**NOTE: Deleting state means that you lose the ability to manage your current terraform resources! Be sure to only
delete once you have confirmed all resources are destroyed.**

Once all the resources for an environment have been destroyed, you can remove the state objects managed by `terragrunt`.
The reference architecture manages state for each environment in an S3 bucket in each environment's AWS account.
Additionally, to prevent concurrent access to the state, it also utilizes a DynamoDB table to manage locks.

To delete the state objects, login to the console and look for the S3 bucket in the environment you wish to undeploy. It
should begin with your company's name and end with `terraform-state`. Also look for a DynamoDB
table named `terraform-locks`. You can safely remove both **once you have confirmed all the resources have been
destroyed successfully**.






## Known errors

There are a few reasons your call to `destroy` may fail:

1. **Terraform bugs**: Terraform has a couple bugs ([18197](https://github.com/hashicorp/terraform/issues/18197) and 
   [17862](https://github.com/hashicorp/terraform/issues/17862)) that may give the following error when you run 
   `destroy`:
   
    ```
    variable "xxx" is nil, but no error was reported
    ```
    
    This usually happens when the module already had `destroy` called on it previously and you re-run `destroy`. In
    this case, your best bet is to skip over that module with the `--terragrunt-exclude-dir` (as shown in the previous)
    section. 

1. **Missing dependencies**: If you delete modules in the wrong order, as discussed in the [Pre-requisite: understand 
   module dependencies](#pre-requisite-understand-module-dependencies) section, then when you try to `destroy` on a
   module that's missing one of its dependencies, you'll get an error about a `data` source being unable to find the
   data it's looking for. Unfortunately, there are no good solutions in this scenario, just a few nasty workarounds: 
   
    1. Run `apply` to temporarily bring back the dependencies.
    1. Update the code to temporarily remove the dependencies and replace them with some mock data.





## Next steps

Now that you know how to undeploy the Reference Architecture, let's take a look at [how to deploy it from 
scratch](07-deploy-from-scratch.md).
