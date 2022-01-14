# ---------------------------------------------------------------------------------------------------------------------
# COMMON TERRAGRUNT CONFIGURATION
# This is the common component configuration for services/k8s-sample-app-backend. The common variables for each environment to
# deploy services/k8s-sample-app-backend are defined here. This configuration will be merged into the environment configuration
# via an include block.
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/k8s-service?ref=v0.70.0"
  source = "${get_parent_terragrunt_dir()}/../../../../..//modules/services/k8s-service"
}

# ---------------------------------------------------------------------------------------------------------------------
# Dependencies are modules that need to be deployed before this one.
# ---------------------------------------------------------------------------------------------------------------------
dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../../networking/vpc"

  mock_outputs = {
    vpc_id = "vpc-abcd1234"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "eks_cluster" {
  config_path = "${get_terragrunt_dir()}/../eks-cluster"

  mock_outputs = {
    eks_cluster_name = "${local.name_prefix}-${local.account_name}"
    eks_iam_role_for_service_accounts_config = {
      openid_connect_provider_arn = "arn:aws:::openid"
      openid_connect_provider_url = "https://openid"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "eks_applications_namespace" {
  config_path = "${get_terragrunt_dir()}/../eks-applications-namespace"

  mock_outputs = {
    namespace_name = "applications"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "eks_core_services" {
  # We don't need any outputs from this module: we only want to register this module as a dependency
  # so that terragrunt will deploy the core services module before this one.
  config_path  = "${get_terragrunt_dir()}/../eks-core-services"
  skip_outputs = true
}
dependency "memcached" {
  config_path = "${get_terragrunt_dir()}/../../data-stores/memcached"

  mock_outputs = {
    configuration_endpoint = "cache"
    cache_port             = 6379
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

dependency "sns" {
  config_path = "${get_terragrunt_dir()}/../../../_regional/sns-topic"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:123456789012:mytopic-NZJ5JSMVGFIE"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}

# ---------------------------------------------------------------------------------------------------------------------
# Generators are used to generate additional Terraform code that is necessary to deploy a module.
# ---------------------------------------------------------------------------------------------------------------------

# Generate a Kubernetes provider configuration for authenticating against the EKS cluster.
generate "k8s_helm" {
  path      = "k8s_helm_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile(
    find_in_parent_folders("provider_k8s_helm_for_eks.template.hcl"),
    { eks_cluster_name = dependency.eks_cluster.outputs.eks_cluster_name },
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# Locals are named constants that are reusable within the configuration.
# ---------------------------------------------------------------------------------------------------------------------
locals {
  source_base_url = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/k8s-service"

  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name and account_role for easy access
  account_name = local.account_vars.locals.account_name
  account_role = local.account_vars.locals.account_role

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

  # A unique name to assign the service.
  service_name = "sample-app-backend"

  # The port that the service listens to within the container.
  container_port = 8443
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above.
# This defines the parameters that are common across all environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  application_name = "${local.service_name}-${local.account_name}"
  namespace        = dependency.eks_applications_namespace.outputs.namespace_name

  # For the backend app, we do not need to expose the service publicly, so we make the service only accessible from
  # within the Kubernetes cluster and also avoid binding a public DNS record to it.
  expose_type          = "cluster-internal"
  create_route53_entry = false

  # Configure the port that the Kubernetes Service resource should listen on. This would be the port used to access the
  # service from within the Kubernetes cluster (e.g., other Pods in the cluster).
  service_port = 8443

  # Configure the container that should run for each Pod. Here, we use the publicly available Gruntwork sample app image
  # from DockerHub.
  # NOTE: The specific tag to deploy will be injected by the child config in a deep merge.
  container_image = {
    repository  = "gruntwork/aws-sample-app"
    pull_policy = "IfNotPresent"
  }

  container_port         = local.container_port
  desired_number_of_pods = 1

  # tmpfs paths to use for Secrets Manager scratch space. At runtime, the container will load the secrets from AWS
  # Secrets Manager and download to this directory.
  scratch_paths = {
    secrets-manager-scratch = "/mnt/secrets/backend-secrets"
  }

  # Configure environment variables to use when running the application. These are configuration options unique to the
  # Gruntwork sample app.
  # NOTE: Some environment variables are environment specific, and need to be configured in the child config. Those will
  # be merged with this config in a deep merge.
  env_vars = {
    CONFIG_APP_NAME                       = "backend"
    CONFIG_APP_ENVIRONMENT_NAME           = local.account_role
    CONFIG_SECRETS_DIR                    = "/mnt/secrets"
    CONFIG_SECRETS_SECRETS_MANAGER_REGION = local.aws_region
    CONFIG_CACHE_ENGINE                   = "memcached"
    CONFIG_CACHE_HOST                     = dependency.memcached.outputs.configuration_endpoint
    CONFIG_CACHE_PORT                     = tostring(dependency.memcached.outputs.cache_port)
    CONFIG_DATABASE_HOST                  = "database"
    CONFIG_DATABASE_RUN_SCHEMA_MIGRATIONS = "true"
    CONFIG_DATABASE_POOL_SIZE             = 10
  }

  # Configure the liveness probe (whether or not the container is up).
  enable_liveness_probe   = true
  liveness_probe_port     = local.container_port
  liveness_probe_protocol = "HTTPS"
  liveness_probe_path     = "/health"

  # Configure the readiness probe (whether or not the container is ready to accept traffic).
  enable_readiness_probe   = true
  readiness_probe_port     = local.container_port
  readiness_probe_protocol = "HTTPS"
  readiness_probe_path     = "/greeting"

  # Configure an IAM role to bind to the Service Account of the service, so that the Pods of the service can access the
  # Secrets Manager entries.
  service_account_name                     = "gruntwork-${local.service_name}"
  iam_role_name                            = "gruntwork-${local.service_name}"
  eks_iam_role_for_service_accounts_config = dependency.eks_cluster.outputs.eks_iam_role_for_service_accounts_config
  iam_role_exists                          = false
  # NOTE: The specific Secrets Manager entries to grant access to for the IAM policy are environment specific, and those
  # will be merged with this config in a deep merge.
  iam_policy = {
    SecretsManagerAccess = {
      actions = ["secretsmanager:GetSecretValue"],
      effect  = "Allow"
    }
  }
}