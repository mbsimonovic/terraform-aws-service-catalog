# This is the configuration for Terragrunt, a thin wrapper for Terraform: https://terragrunt.gruntwork.io/

# Include the root `terragrunt.hcl` configuration, which has settings common across all environments & components.
include "root" {
  path = find_in_parent_folders()
}

# Include the component configuration, which has settings that are common for the component across all environments
include "envcommon" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/services/asg-sample-app.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}


# Include the envcommon configuration for the sample app in frontend mode.
include "frontend" {
  path = "${dirname(find_in_parent_folders())}/_envcommon/services/asg-sample-app-frontend.hcl"
  # We want to reference the variables from the included config in this configuration, so we expose it.
  expose = true
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  common_vars = include.envcommon.locals.common_vars

  # Specify the AMI version here so that it can be overridden in a CI/CD pipeline.
  ami_version = "v0.0.5"
}

# ---------------------------------------------------------------------------------------------------------------------
# Module parameters to pass in. Note that these parameters are environment specific.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {

  ami = ""
  ami_filters = {
    owners = [local.common_vars.locals.account_ids.shared]
    filters = [
      {
        name   = "name"
        values = ["aws-sample-app-${local.ami_version}-*"]
      },
    ]
  }

  # Setup configurations that are dependent on the Secrets Manager entries in this specific environment.
  cloud_init_parts = {
    gruntwork-sample-app = {
      filename     = "gruntwork-sample-app"
      content_type = "text/x-shellscript"
      content = templatefile(
        include.envcommon.locals.user_data_template_path,
        merge(
          include.frontend.inputs._base_user_data_template_vars,
          {
            external_account_ssh_grunt_role_arn = include.envcommon.locals.external_account_ssh_grunt_role_arn
            tls_config_secrets_manager_arn      = "arn:aws:secretsmanager:us-west-2:345678901234:secret:TLSFrontEndSecretsManagerArn-abcd1234"
            db_config_secrets_manager_arn       = ""
            secrets_manager_config = yamlencode({
              secretsManager = {
                region = include.frontend.locals.aws_region
                dbId   = ""
                tlsId  = "arn:aws:secretsmanager:us-west-2:345678901234:secret:TLSFrontEndSecretsManagerArn-abcd1234"
              }
            })
          },
        ),
      )
    }
  }
  secrets_access = [
    "arn:aws:secretsmanager:us-west-2:345678901234:secret:TLSFrontEndSecretsManagerArn-abcd1234",
  ]
}