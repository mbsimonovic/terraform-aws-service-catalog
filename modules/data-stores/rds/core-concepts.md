## How do I use Kubernetes Service Discovery with the RDS Database?

You can register the RDS database endpoint to the internal DNS service used by Kubernetes by creating a Kubernetes
[Service resource](https://kubernetes.io/docs/concepts/services-networking/service/) of type
[ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname) that can be used to route
requests against that Service to the primary endpoint of the RDS database. We recommend using the Service DNS Mapping
feature of the [eks-core-services module](../../services/eks-core-services) to bind the primary endpoint of the RDS
database to a Kubernetes Service. See the [relevant
documentation](../../services/eks-core-services/core-concepts.md#how-do-i-register-external-services-to-internal-dns)
for more information.

## How do I pass database configuration securely?

This module can read the database configuration from AWS Secrets Manager so that you can avoid passing secrets as 
variables.

First, create a secret in Secrets Manager using the AWS web console. The secret should be in JSON format, [as outlined here](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html#best-practice_what-not-to-put-in-secret-text). 

For example:

```
{
  "engine": "mysql",
  "username": "example-username",
  "password": "example-password",
  "dbname": "example-db",
  "port": "3306"
}
```

Give the secret a name. When calling this module, set `var.db_config_secrets_manager_id` to the name. The module will read the value and use it to configure the RDS instance.

If you do not wish to use AWS Secrets Manager, you can use the individual variables (e.g. `var.engine`, `var.master_username`, `var.master_password`, etc). Refer to the Gruntwork blog post [A comprehensive guide to managing secrets in your Terraform code](https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1) for information on how to safely manage secrets with Terraform.
