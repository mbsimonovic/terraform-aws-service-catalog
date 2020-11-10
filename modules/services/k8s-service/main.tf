# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A KUBERNETES DEPLOYMENT AND SERVICE WITH AN INGRESS RESOURCE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.26, which knows what to do with the source syntax of required_providers.
  # Make sure we don't accidentally pull in 0.13.x, as that has backwards incompatible changes that are known to NOT
  # work with the terraform-aws-eks repo. We are working on a fix, but until that's ready, we need to avoid 0.13.x.
  required_version = "~> 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }

    # Pin to this specific version to work around a bug introduced in 1.11.0:
    # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
    # (Only for EKS)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 1.10.0"
    }

    # This module uses Helm 3, which depends on helm provider version 1.x series.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 1.0"
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY DOCKERIZED APP USING k8s-service HELM CHART
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "application" {
  name       = var.application_name
  repository = "https://helmcharts.gruntwork.io"
  chart      = "k8s-service"
  version    = "v0.1.1"
  namespace  = var.namespace

  values = [yamlencode(local.helm_chart_input)]

  # external-dns and AWS ALB Ingress controller will turn the Ingress resources from the chart into AWS resources. These
  # are properly destroyed when the Ingress resource is destroyed. However, because of the asynchronous nature of
  # Kubernetes operations, there is a delay before the respective controllers delete the AWS resources. This can cause
  # problems when you are destroying related resources in quick succession (e.g the Route 53 Hosted Zone). Since we want
  # to add a wait after the release is destroyed, we need to use a null_resource to add the delay instead of a destroy
  # provisioner on the resource, as the destroy provisioner typically runs before the resource is deleted.
  # By depending on the null_resource, the destroy sequence will be:
  # 1. Destroy this resource (and thus undeploy the application from the cluster)
  # 2. Run the destroy provisioner on null_resource.sleep_for_resource_culling
  # 3. Destroy null_resource.sleep_for_resource_culling
  depends_on = [null_resource.sleep_for_resource_culling]
}

resource "null_resource" "sleep_for_resource_culling" {
  triggers = {
    should_run = var.expose_type != "cluster-internal" ? "true" : "false"
  }

  provisioner "local-exec" {
    command = (
      self.triggers["should_run"] == "true"
      ? "echo 'Sleeping for 30 seconds to allow Kubernetes time to remove associated AWS resources'; sleep 30"
      : "echo 'Skipping sleep to wait for Kubernetes to cull AWS resources, since k8s-service has none associated with it.'"
    )
    when = destroy
  }
}

locals {
  # Map the var.secrets_as_volumes and var.secrets_as_env_vars into the format expected by the helm chart.
  secrets = merge(
    {
      for key, mount_path in var.secrets_as_volumes :
      key => {
        as        = "volume"
        mountPath = mount_path
      }
    },
    {
      for key, env_items in var.secrets_as_env_vars :
      key => {
        as = "environment"
        items = {
          for secret_key, env_var_name in env_items :
          secret_key => {
            envVarName = env_var_name
          }
        }
      }
    },
  )

  # Map the var.configmaps_as_volumes and var.configmaps_as_env_vars into the format expected by the helm chart.
  configmaps = merge(
    {
      for key, mount_path in var.configmaps_as_volumes :
      key => {
        as        = "volume"
        mountPath = mount_path
      }
    },
    {
      for key, env_items in var.configmaps_as_env_vars :
      key => {
        as = "environment"
        items = {
          for configmap_key, env_var_name in env_items :
          configmap_key => {
            envVarName = env_var_name
          }
        }
      }
    },
  )

  iam_role = (
    var.iam_role_name != ""
    ? (
      var.iam_role_exists
      ? data.aws_iam_role.existing_role[0].arn
      : aws_iam_role.new_role[0].arn
    )
    : ""
  )

  alb_health_check = {
    "alb.ingress.kubernetes.io/healthcheck-port"             = var.alb_health_check_port
    "alb.ingress.kubernetes.io/healthcheck-protocol"         = var.alb_health_check_protocol
    "alb.ingress.kubernetes.io/healthcheck-path"             = var.alb_health_check_path
    "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = tostring(var.alb_health_check_interval)
    "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = tostring(var.alb_health_check_timeout)
    "alb.ingress.kubernetes.io/healthy-threshold-count"      = tostring(var.alb_health_check_healthy_threshold)
    "alb.ingress.kubernetes.io/success-codes"                = var.alb_health_check_success_codes
  }

  # Assemble a complete map of ingress annotations
  ingress_annotations = merge(
    {
      "kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = var.expose_type == "external" ? "internet-facing" : "internal"
      # We manually construct the list as a string here to avoid the values being converted as string, as opposed to
      # ints
      "alb.ingress.kubernetes.io/listen-ports"             = "[${join(",", data.template_file.ingress_listener_protocol_ports.*.rendered)}]"
      "alb.ingress.kubernetes.io/backend-protocol"         = var.ingress_backend_protocol
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "access_logs.s3.enabled=true,access_logs.s3.bucket=${module.alb_access_logs_bucket.s3_bucket_name},access_logs.s3.prefix=${var.application_name}"
    },
    try(
      var.ingress_configure_ssl_redirect
      ? {
        "alb.ingress.kubernetes.io/actions.ssl-redirect" : "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}",
      }
      : tomap(false),
      {},
    ),
    {
      "alb.ingress.kubernetes.io/certificate-arn" : join(",", var.alb_acm_certificate_arns),
    },
    local.alb_health_check,
    var.ingress_annotations,

  )

  # Refer to the values.yaml file for helm-kubernetes-services/k8s-service for more information on the available input
  # parameters:
  # https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/charts/k8s-service/values.yaml
  helm_chart_input = {
    applicationName = var.application_name
    containerImage = {
      repository = var.container_image["repository"]
      tag        = var.container_image["tag"]
      pullPolicy = var.container_image["pull_policy"]
    }
    canary = {
      enabled      = var.desired_number_of_canary_pods > 0
      replicaCount = var.desired_number_of_canary_pods
      # Workaround for deep type checker. See https://github.com/hashicorp/terraform/issues/22405 for more info.
      containerImage = try(
        var.canary_image != null
        ? {
          repository = var.canary_image["repository"]
          tag        = var.canary_image["tag"]
          pullPolicy = var.canary_image["pull_policy"]
        }
        : tomap(false),
        {},
      )
    }
    containerPorts = {
      http = {
        port     = var.container_port
        protocol = var.container_protocol
      }
      liveness = {
        port     = var.liveness_probe_port
        protocol = "TCP"
      }
      readiness = {
        port     = var.readiness_probe_port
        protocol = "TCP"
      }
    }
    replicaCount = var.desired_number_of_pods

    service = {
      # When expose_type is cluster-internal, we do not want to associate an Ingress resource, or allow access
      # externally from the cluster, so we use ClusterIP service type.
      type = var.expose_type == "cluster-internal" ? "ClusterIP" : "NodePort"
      ports = {
        app = {
          port = var.service_port
        }
      }
    }

    serviceAccount = {
      # Create a new service account if service_account_name is not blank and it is not referring to an existing Service
      # Account
      create = (! var.service_account_exists) && var.service_account_name != ""

      name        = var.service_account_name
      namespace   = var.namespace
      annotations = local.iam_role == "" ? {} : { "eks.amazonaws.com/role-arn" = local.iam_role }
    }

    ingress = {
      enabled     = var.expose_type != "cluster-internal"
      path        = "'${var.ingress_path}'"
      hosts       = var.domain_name != null ? [var.domain_name] : []
      servicePort = "app"
      annotations = local.ingress_annotations
      # Only configure the redirect path if using ssl redirect
      additionalPathsHigherPriority = (
        var.ingress_configure_ssl_redirect
        ? [{
          path        = "/*"
          serviceName = "ssl-redirect"
          servicePort = "use-annotation"
        }]
        : []
      )
    }

    envVars    = var.env_vars
    configMaps = local.configmaps
    secrets    = local.secrets

    # Workaround for deep type checker. See https://github.com/hashicorp/terraform/issues/22405 for more info.
    livenessProbe = try(
      var.enable_liveness_probe
      ? {
        httpGet = {
          port   = var.liveness_probe_port
          path   = var.liveness_probe_path
          scheme = var.liveness_probe_protocol
        }
        initialDelaySeconds = var.liveness_probe_grace_period_seconds
        periodSeconds       = var.liveness_probe_interval_seconds
      }
      : tomap(false),
      {},
    )
    readinessProbe = try(
      var.enable_readiness_probe
      ? {
        httpGet = {
          port   = var.readiness_probe_port
          path   = var.readiness_probe_path
          scheme = var.readiness_probe_protocol
        }
        initialDelaySeconds = var.readiness_probe_grace_period_seconds
        periodSeconds       = var.readiness_probe_interval_seconds
      }
      : tomap(false),
      {},
    )
  }
}

# We use a template file here to construct a list of protocol port mappings for the listener, that can then be injected
# into the input values. We do this instead of directly rendering the list because terraform does some type conversions
# in the yaml encode process.
data "template_file" "ingress_listener_protocol_ports" {
  count    = length(var.ingress_listener_protocol_ports)
  template = "{\"${var.ingress_listener_protocol_ports[count.index]["protocol"]}\": ${var.ingress_listener_protocol_ports[count.index]["port"]}}"
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE S3 BUCKETS FOR ALB LOGS
# When Ingress is enabled (expose_type = internal or external), we need to create S3 buckets to store the ALB access
# logs.
# ---------------------------------------------------------------------------------------------------------------------

module "alb_access_logs_bucket" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/logs/load-balancer-access-logs?ref=v0.23.3"
  create_resources = var.expose_type != "cluster-internal"

  s3_bucket_name    = local.access_logs_s3_bucket_name
  s3_logging_prefix = var.application_name

  num_days_after_which_archive_log_data = var.num_days_after_which_archive_ingress_log_data
  num_days_after_which_delete_log_data  = var.num_days_after_which_delete_ingress_log_data

  force_destroy = var.force_destroy_ingress_access_logs
}

locals {
  # Try to do some basic cleanup to get a valid S3 bucket name: the name must be lower case and can only contain
  # lowercase letters, numbers, and hyphens. For the full rules, see:
  # http://docs.aws.amazon.com/AmazonS3/latest/dev/BucketRestrictions.html#bucketnamingrules
  default_access_logs_s3_bucket_name = "alb-${lower(replace(var.application_name, "_", "-"))}-access-logs"

  access_logs_s3_bucket_name = length(var.ingress_access_logs_s3_bucket_name) > 0 ? var.ingress_access_logs_s3_bucket_name : local.default_access_logs_s3_bucket_name
}


# ---------------------------------------------------------------------------------------------------------------------
# SET UP IAM ROLE FOR SERVICE ACCOUNT
# Set up IRSA if a service account and IAM role are configured.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "new_role" {
  count              = var.iam_role_name != "" && var.iam_role_exists == false ? 1 : 0
  name               = var.iam_role_name
  assume_role_policy = module.service_account_assume_role_policy.assume_role_policy_json
}

module "service_account_assume_role_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-iam-role-assume-role-policy-for-service-account?ref=v0.27.2"

  eks_openid_connect_provider_arn = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_arn
  eks_openid_connect_provider_url = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_url
  namespaces                      = []
  service_accounts = [{
    name      = var.service_account_name
    namespace = var.namespace
  }]
}

resource "aws_iam_role_policy" "service_policy" {
  count  = var.iam_role_name != "" && var.iam_role_exists == false ? 1 : 0
  name   = "${var.iam_role_name}Policy"
  role   = var.iam_role_name != "" && var.iam_role_exists == false ? aws_iam_role.new_role[0].id : data.aws_iam_role.existing_role[0].id
  policy = data.aws_iam_policy_document.service_policy[0].json
}

data "aws_iam_policy_document" "service_policy" {
  count = var.iam_role_name != "" ? 1 : 0

  dynamic "statement" {
    for_each = var.iam_policy == null ? {} : var.iam_policy

    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

data "aws_iam_role" "existing_role" {
  count = var.iam_role_exists ? 1 : 0
  name  = var.iam_role_name
}

# ---------------------------------------------------------------------------------------------------------------------
# EMIT HELM CHART VALUES TO DISK FOR DEBUGGING
# ---------------------------------------------------------------------------------------------------------------------

resource "local_file" "debug_values" {
  count           = var.values_file_path != null ? 1 : 0
  content         = yamlencode(local.helm_chart_input)
  filename        = var.values_file_path
  file_permission = "0644"
}
