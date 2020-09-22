# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY SERVICE ON KUBERNETES USING THE K8S-SERVICE HELM CHART
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  # Skip all checks if not using eks auth, as they are unnecessary.
  skip_credentials_validation = var.kubeconfig_auth_type != "eks"
  skip_get_ec2_platforms      = var.kubeconfig_auth_type != "eks"
  skip_region_validation      = var.kubeconfig_auth_type != "eks"
  skip_requesting_account_id  = var.kubeconfig_auth_type != "eks"
  skip_metadata_api_check     = var.kubeconfig_auth_type != "eks"
}

# Configure the kubernetes and Helm providers based on the requested authentication type.
provider "kubernetes" {
  # Pin to this specific version to work around a bug introduced in 1.11.0:
  # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
  # (Only for EKS)
  version = "= 1.10.0"

  # If using `context`, load the authentication info from the config file and chosen context.
  load_config_file = var.kubeconfig_auth_type == "context"
  config_path      = var.kubeconfig_auth_type == "context" ? var.kubeconfig_path : null
  config_context   = var.kubeconfig_auth_type == "context" ? var.kubeconfig_context : null

  # If using `eks`, load the authentication info directly from EKS.
  host                   = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster.cluster[0].endpoint : null
  cluster_ca_certificate = var.kubeconfig_auth_type == "eks" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : null
  token                  = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster_auth.kubernetes_token[0].token : null
}

provider "helm" {
  kubernetes {
    # If using `context`, load the authentication info from the config file and chosen context.
    load_config_file = var.kubeconfig_auth_type == "context"
    config_path      = var.kubeconfig_auth_type == "context" ? var.kubeconfig_path : null
    config_context   = var.kubeconfig_auth_type == "context" ? var.kubeconfig_context : null

    # If using `eks`, load the authentication info directly from EKS.
    host                   = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster.cluster[0].endpoint : null
    cluster_ca_certificate = var.kubeconfig_auth_type == "eks" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : null
    token                  = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster_auth.kubernetes_token[0].token : null
  }
}

module "application" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/k8s-service?ref=v1.0.8"
  source = "../../../../modules/services/k8s-service"

  application_name = var.application_name
  container_image = {
    repository = var.image
    tag        = var.image_version
    # We use IfNotPresent here to optimize and encourage usage of immutable tags. You may want to use different policies
    # dependending on your use case. E.g., if you wish to test locally and want to continuously push to the latest tag,
    # you can use `Always`.
    pull_policy = "IfNotPresent"
  }
  container_port         = var.container_port
  namespace              = var.namespace
  expose_type            = var.expose_type
  desired_number_of_pods = 1

  create_route53_entry = var.domain_name != null
  domain_name          = var.domain_name != null ? var.domain_name : ""

  # This is an example of how to configure hard coded environment variables that are necessary for running your app.
  env_vars = {
    CONFIG_APP_NAME             = "frontend"
    CONFIG_APP_ENVIRONMENT_NAME = var.app_environment_name
    CONFIG_SERVER_HTTP_PORT     = var.container_port
    CONFIG_SECRETS_DIR          = "/mnt/secrets"

    # Disable HTTPS endpoint for test purposes.
    NODE_CONFIG = jsonencode({
      server = {
        httpsPort = null
      }
    })
  }

  # These variables can be used for configuring dynamic data that is managed separately from the app deployment.
  # ConfigMaps are recommended for configuration data that are not sensitive, while Secrets are recommended for
  # sensitive data.
  configmaps_as_env_vars = var.configmaps_as_env_vars
  secrets_as_env_vars    = var.secrets_as_env_vars

  # If you want to debug the Helm chart, you can set this parameter to output the chart values to a file
  values_file_path = "${path.module}/debug_values.yaml"

  # Configure liveness and readiness probes to the sample app health endpoint.
  # Liveness is used to indicate if the Pod is alive and used to determine if the Pod needs to be restarted.
  # Readiness is used to indicate if the Pod is ready to receive traffic, and used to determine if the Pod should be
  # included in Service endpoints.
  # For the sample app, we use the same endpoint for both checks but in your real application, you may want to use
  # different endpoints for each probe.
  enable_liveness_probe  = true
  liveness_probe_port    = var.container_port
  liveness_probe_path    = "/health"
  enable_readiness_probe = true
  readiness_probe_port   = var.container_port
  readiness_probe_path   = "/health"

  # To make it easier to test, we allow force destroying the ALB access logs but in production, you will want to set
  # this to false so that the access logs are not accidentally destroyed permanently.
  force_destroy_ingress_access_logs  = true
  ingress_access_logs_s3_bucket_name = "gw-service-catalog-test-${var.application_name}-alb-access-logs"
}
