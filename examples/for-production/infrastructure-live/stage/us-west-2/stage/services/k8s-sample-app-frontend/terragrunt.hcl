# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# This is the configuration for Terragrunt, a thin wrapper for Terraform that helps keep your code DRY and
# maintainable: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder. If you're iterating
# locally, you can use --terragrunt-source /path/to/local/checkout/of/module to override the source parameter to a
# local check out of the module for faster iteration.
terraform {
  # We're using a local file path here just so our automated tests run against the absolute latest code. However, when
  # using these modules in your code, you should use a Git URL with a ref attribute that pins you to a specific version:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/services/k8s-service?ref=v0.38.1"
  source = "${get_parent_terragrunt_dir()}/../../..//modules/services/k8s-service"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

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



dependency "sns" {
  config_path = "${get_terragrunt_dir()}/../../../_regional/sns-topic"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-1:123456789012:mytopic-NZJ5JSMVGFIE"
  }
  mock_outputs_allowed_terraform_commands = ["validate", ]
}





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
  # Automatically load common variables shared across all accounts
  common_vars = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  # Extract the name prefix for easy access
  name_prefix = local.common_vars.locals.name_prefix

  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Extract the account_name for easy access
  account_name = local.account_vars.locals.account_name

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the region for easy access
  aws_region = local.region_vars.locals.aws_region

  # A unique name to assign the service.
  service_name = "sample-app-frontend"

  # The port that the service listens to within the container.
  container_port = 8443

  # The Secrets Manager ARN of an entry containing the TLS certificate keypair that the service should use for End-to-End
  # encryption.
  tls_secrets_manager_arn = "arn:aws:secretsmanager:us-west-2:456789012345:secret:TLSFrontEndSecretsManagerArn-abcd1234"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  application_name = "${local.service_name}-${local.account_name}"
  namespace        = dependency.eks_applications_namespace.outputs.namespace_name

  # For the frontend app, make the service publicly accessible behind an AWS ALB, and configure a unique name for the S3
  # bucket to store the Access Logs for the ALB.
  expose_type                        = "external"
  ingress_access_logs_s3_bucket_name = "${local.name_prefix}-${local.account_name}-${local.service_name}-access-logs"

  # Make sure that all requests to the ALB for the given hostname routes to the Pods, and that the ALB uses HTTPS to
  # when forwarding requests to the Pods (for End to End encryption).
  ingress_path             = "/*"
  ingress_backend_protocol = "HTTPS"

  # To make the service easier to discover, bind a domain name to the service from our Route 53 Public Hosted Zone.
  create_route53_entry = true
  domain_name          = "gruntwork-sample-app.${local.account_vars.locals.domain_name.name}"

  # Configure Health checks that the ALB can use to determine if a Pod is healthy enough to route to.
  alb_health_check_protocol      = "HTTPS"
  alb_health_check_port          = "traffic-port"
  alb_health_check_success_codes = "200"
  alb_health_check_path          = "/health"

  # Configure the port that the Kubernetes Service resource should listen on. This would be the port used to access the
  # service from within the Kubernetes cluster (e.g., other Pods in the cluster).
  service_port = 8443

  # Configure the container that should run for each Pod. Here, we use the publicly available Gruntwork sample app image
  # from DockerHub.
  container_image = {
    repository  = "gruntwork/aws-sample-app"
    tag         = "v0.0.4"
    pull_policy = "IfNotPresent"
  }

  container_port         = local.container_port
  desired_number_of_pods = 1

  # tmpfs paths to use for Secrets Manager scratch space. At runtime, the container will load the secrets from AWS
  # Secrets Manager and download to this directory.
  scratch_paths = {
    secrets-manager-scratch = "/mnt/secrets/frontend-secrets"
  }

  # Configure environment variables to use when running the application. These are configuration options unique to the
  # Gruntwork sample app.
  env_vars = {
    CONFIG_APP_NAME                       = "frontend"
    CONFIG_APP_ENVIRONMENT_NAME           = local.account_name
    CONFIG_SECRETS_DIR                    = "/mnt/secrets"
    CONFIG_SECRETS_SECRETS_MANAGER_TLS_ID = local.tls_secrets_manager_arn
    CONFIG_SECRETS_SECRETS_MANAGER_REGION = local.aws_region
    CONFIG_SERVICES = jsonencode({
      backend = {
        host     = "sample-app-backend-${local.account_vars.locals.account_name}.applications.svc.cluster.local"
        port     = 8443
        protocol = "https"
        ca       = "tls/CA-backend.crt"
      }
    })
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
  service_account_name                     = "gruntwork-sample-app-frontend"
  iam_role_name                            = "gruntwork-sample-app-frontend"
  eks_iam_role_for_service_accounts_config = dependency.eks_cluster.outputs.eks_iam_role_for_service_accounts_config
  iam_role_exists                          = false
  iam_policy = {
    SecretsManagerAccess = {
      actions = ["secretsmanager:GetSecretValue"],
      resources = [
        local.tls_secrets_manager_arn,

      ]
      effect = "Allow"
    }
  }
}