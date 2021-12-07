# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/services/ecs-sample-app-frontend.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  tls_secrets_manager_arn = "arn:aws:secretsmanager:us-west-2:456789012345:secret:TLSFrontEndSecretsManagerArn-abcd1234"

  # List of environment variables and container images for each container that are specific to this environment. The map
  # key here should correspond to the map keys of the _container_definitions_map input defined in envcommon.
  service_environment_variables = {
    (include.envcommon.locals.service_name) = [
      {
        name  = "CONFIG_SECRETS_SECRETS_MANAGER_TLS_ID"
        value = local.tls_secrets_manager_arn
      },
    ]
  }
  container_images = {
    (include.envcommon.locals.service_name) = "${include.envcommon.locals.container_image}:${local.tag}"
  }

  # Specify the app image tag here so that it can be overridden in a CI/CD pipeline.
  tag = "v0.0.2"
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # The Container definitions of the ECS service. The following environment specific parameters are injected into the
  # common definition defined in the envcommon config:
  # - Image tag
  # - Secrets manager ARNs
  container_definitions = [
    for name, definition in include.envcommon.inputs._container_definitions_map :
    merge(
      definition,
      {
        name        = name
        image       = local.container_images[name]
        environment = concat(definition.environment, local.service_environment_variables[name])
      },
    )
  ]

  # -------------------------------------------------------------------------------------------------------------
  # IAM permissions
  # Grant the necessary IAM permissions to the ECS service so that it can read the Secrets Manager entries.
  # -------------------------------------------------------------------------------------------------------------

  secrets_access = [
    local.tls_secrets_manager_arn,
  ]
}