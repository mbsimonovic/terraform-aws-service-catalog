# Adding a new account

This document is a guide to how to add a new AWS account into the Reference Architecture. This is useful if you have a
need to expand the Reference Architecture with more accounts, like a test or sandbox account.

1. [Create new Account in your AWS Org](#create-new-account-in-your-aws-org)
1. [Update Logs, Security, and Shared accounts to allow cross account access](#update-logs-security-shared-accounts-to-allow-cross-account-access)
1. [Deploy the security baseline](#deploy-the-security-baseline)
1. [Deploy the ECS Deploy Runner](#deploy-the-ecs-deploy-runner)


## Create new Account in your AWS Org

The first step to adding a new account is to create the new AWS Account in your AWS Organization. This can be done
either through the AWS Web Console, or by using the [Gruntwork CLI](https://github.com/gruntwork-io/gruntwork/). If you
are doing this via the CLI, you can run the following command to create the new account:

```
gruntwork aws create --account "<ACCOUNT_NAME>=<EMAIL_ADDRESS_FOR_ROOT_USER>"
```

Record the account name and AWS ID of the new account you just created in the [accounts.json](/accounts.json) file so
that we can reference it throughout the process.

Once the account is created, log in using the root credentials and configure MFA (see [this
document](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html#enable-virt-mfa-for-root)
for instructions on how to configure this). It is critical to enable MFA as the root user can bypass just about any
other security restrictions you put in place. Make sure you keep a paper copy of the virtual device secret key so that
you have a backup in case you lose your MFA device.

Once MFA is configured, set up a temporary IAM user with administrator access (the AWS managed IAM policy
`AdministratorAccess`) and create an AWS Access key pair so you can authenticate on the command line.

At this point, you won't need to use the root credentials again until you are ready to delete the AWS account.


## Update Logs, Security, and Shared accounts to allow cross account access

In the Reference Architecture, all the AWS activity logs are configured to be streamed to a dedicated `logs` account.
This ensures that having full access to a particular account does not necessarily grant you the ability to tamper with
audit logs.

In addition, all account access is managed by a central `security` account where the IAM users are defined. This allows
you to manage access to accounts from a central location, and your users only need to manage a single set of AWS
credentials when accessing the environment.

Finally, for the [ECS Deploy
Runner](https://github.com/gruntwork-io/terraform-aws-ci/tree/master/modules/ecs-deploy-runner) to work, the new account
needs to be able to access the secrets for accessing the remote repositories and the docker images that back the build
runners. Both of these are stored in the `shared` account.

In order for this setup to work for each new account that is created, the `logs`, `security`, and `shared` accounts need
to be made aware of the new account. This is handled through the [accounts.json](/accounts.json) file in your
`infrastructure-live` repository.

Once the `accounts.json` file is updated with the new account, you will want to grant the permissions for the new
account to access the shared resources. This can be done by running `terragrunt apply` in the `account-baseline` module
for the `logs` and `security` account, and the `ecr-repos` and `shared-secret-resource-policies` modules in the `shared`
account:

```
(cd logs/_global/account-baseline && terragrunt apply)
(cd security/_global/account-baseline && terragrunt apply)
(cd shared/us-west-2/_regional/ecr-repos && terragrunt apply)
(cd shared/us-west-2/_regional/shared-secret-resource-policies && terragrunt apply)
```

Each call to apply will show you the plan for making the cross account changes. Verify the plan looks correct, and then
approve it to apply the updated cross account permissions.



## Deploy the security baseline

Now that the cross account access is configured, you are ready to start provisioning the new account!

First, create a new folder for your account in `infrastructure-live`. The folder name should match the name of the AWS
account.

Once the folder is created, create the following folders and files in the new folder:

- `account.hcl` - This should have the following contents:

        locals {
          account_name = "<REPLACE_WITH_NAME_OF_ACCOUNT>"
        }

- `_global/region.hcl` - This should have the following contents:

        # Modules in the account _global folder don't live in any specific AWS region, but you still have to send the API calls
        # to _some_ AWS region, so here we pick a default region to use for those API calls.
        locals {
          aws_region = "us-east-1"
        }

Next, copy over the `account-baseline` configuration from one of the application accounts (e.g., `dev`) and place it in
the `_global` folder:

```
cp -r dev/_global/account-baseline <REPLACE_WITH_NAME_OF_ACCOUNT>/_global/account-baseline
```

Open the `terragrunt.hcl` file in the `account-baseline` folder and sanity check the configuration. Make sure there are
no hard coded parameters that are specific to the dev account. If you have not touched the configuration since the
Reference Architecture was deployed, you won't need to change anything.

At this point, your folder structure for the new account should look like the following:

```
.
└── new-account
    ├── account.hcl
    └── _global
        ├── region.hcl
        └── account-baseline
            └── terragrunt.hcl
```

Once the folder structure looks correct and you have confirmed the `terragrunt.hcl` configuration is accurate, you are
ready to deploy the security baseline. Authenticate to the new account on the CLI (see [this blog
post](https://blog.gruntwork.io/a-comprehensive-guide-to-authenticating-to-aws-on-the-command-line-63656a686799) for
instructions) using the access credentials for the temporary IAM user you created above and run `terragrunt apply`.

When running `apply`, you will see the plan for applying all the security baseline to the new account. Verify the plan
looks correct, and then approve it roll out the security baseline.

At this point, you can now use the cross account access from the `security` account to authenticate to the new account.
Use your security account IAM user to assume the `allow-full-access-from-other-accounts` IAM role in the new account to
confirm this. Refer to the [authentication section of this guide](02-authenticate.md) for more details on how to do
this.

Once you confirm you have access to the new account from the `security` account, login using the
`allow-full-access-from-other-accounts` IAM role and remove the temporary IAM user as you will no longer need to use it.


## Deploy the ECS Deploy Runner

Once the security baseline is deployed on the new account, you can deploy the ECS Deploy Runner. With the ECS Deploy
Runner, you will be able to provision new resources in the account using the CI/CD pipeline that you configured in
[Configure Gruntwork Pipelines](04-configure-gw-pipelines.md).

To deploy the ECS Deploy Runner, copy the terragrunt configurations for `mgmt/vpc-mgmt` and `mgmt/ecs-deploy-runner`
from the `dev` account:

```
mkdir -p <REPLACE_WITH_NAME_OF_ACCOUNT>/us-west-2/mgmt
cp -r dev/us-west-2/mgmt/{vpc-mgmt,ecs-deploy-runner} <REPLACE_WITH_NAME_OF_ACCOUNT>/us-west-2/mgmt
```

Be sure to open the `terragrunt.hcl` file in the copied folders and sanity check the configuration. Make sure there are
no hard coded parameters that are specific to the dev account. If you have not touched the configuration since the
Reference Architecture was deployed, you won't need to change anything.

Once the configuration looks correct, go in to the `mgmt` folder and use `terragrunt run-all apply` to deploy the ECS
Deploy Runner:

```
(cd <REPLACE_WITH_NAME_OF_ACCOUNT>/us-west-2/mgmt && terragrunt run-all apply)
```

**NOTE:** Because this uses `run-all`, the command will not pause to show you the plan. If you wish to view the plan,
run `apply` in each subfolder of the `mgmt` folder, in dependency graph order. You can see the dependency graph by using
the [graph-dependencies terragrunt
command](https://terragrunt.gruntwork.io/docs/reference/cli-options/#graph-dependencies).

At this point, the ECS Deploy Runner is provisioned in the new account, and you can start using the Gruntwork Pipeline
to provision new infrastructure in the account.


## Next steps

Now that you know how to add new accounts to the Reference Architecture, let's take a look at [undeploy parts or all of the Reference Architecture](07-undeploy.md).
