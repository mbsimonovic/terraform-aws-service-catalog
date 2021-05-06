# ECS Deploy Runner CI/CD pipeline

This directory manages the ECS deploy runner configuration for the [Gruntwork CI/CD pipeline](https://gruntwork.io/guides/automations/how-to-configure-a-production-grade-ci-cd-setup-for-apps-and-infrastructure-code/).


## Shared secrets

The ECS deploy runner relies on a machine user with access to the Git repositories where your configuration is stored. This allows the deploy runner to pull code, scripts, and utilities from the repositories, and also allows the deploy runner to commit updates (such as Docker image tags and AMI IDs) to the repositories during automated deployments. For this to work, we need to supply the deploy runner with the machine user credentials, including the GitHub Personal Access Token (PAT) and the private SSH key.

Furthermore, the deploy runner is deployed to each account in a multi-account configuration, and is configured to be invoked from a CI/CD system, such as Jenkins or CircleCI, in the shared-services account. This approach allows the deploy runner to be isolated from other accounts. However, this also means that the machine user credentials need to be reused in each account.

We keep the configuration DRY and avoid repeating the same machine user credentials in each account by using the approach described below.

In the shared account:

1. Create a KMS key for shared secrets in the account baseline configuration of the shared account, and share the key with the other accounts.
1. Create AWS Secrets Manager secrets for the GitHub PAT and for the private SSH key, using the KMS key from the previous step.
1. Create a [resource-based policy](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_resource-based-policies.html) for the secrets, granting access to the other accounts.

In each of the other accounts:

1. Use [KMS key grants](https://docs.aws.amazon.com/kms/latest/developerguide/grants.html) to grant access to each of the deploy runner task IAM roles.
1. Grant access to the deploy runner task IAM roles to use the Secrets Manager secrets from the shared account.

With this configuration in place, the credentials can be rotated and updated as necessary in the shared-services account, with no need to modify the other accounts.

