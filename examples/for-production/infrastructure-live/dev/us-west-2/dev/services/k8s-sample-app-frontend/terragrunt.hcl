# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/services/k8s-sample-app-frontend.hcl"
  # Perform a deep merge so that we can reference dependencies in the override parameters.
  merge_strategy = "deep"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # The Secrets Manager ARN of an entry containing the TLS certificate keypair that the service should use for End-to-End
  # encryption.
  tls_secrets_manager_arn = "arn:aws:secretsmanager:us-west-2:345678901234:secret:TLSFrontEndSecretsManagerArn-abcd1234"
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Configure the specific image tag to use when deploying this app. The other configurations are inherited from the
  # parent envcommon configuration.
  container_image = {
    tag = "v0.0.2"
  }

  # Configure environment variables to use when running the application. The other configurations are inherited from the
  # parent envcommon configuration. Here we only specify the values that are unique to this environment.
  env_vars = {
    CONFIG_SECRETS_SECRETS_MANAGER_TLS_ID = local.tls_secrets_manager_arn
  }

  # Configure the IAM policy to allow access to the Secrets Manager entries for this environment.
  iam_policy = {
    SecretsManagerAccess = {
      resources = [
        local.tls_secrets_manager_arn,
      ]
    }
  }
}