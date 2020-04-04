# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A KUBERNETES DEPLOYMENT AND SERVICE WITH AN INGRESS RESOURCE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.20, which added the function try; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.20"

  required_providers {
    aws = "~> 2.6"

    # Pin to this specific version to work around a bug introduced in 1.11.0:
    # https://github.com/terraform-providers/terraform-provider-kubernetes/issues/759
    kubernetes = "= 1.10.0"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY DOCKERIZED APP USING k8s-service HELM CHART
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "application" {
  name       = var.application_name
  repository = "https://helmcharts.gruntwork.io"
  chart      = "k8s-service"
  version    = "v0.1.0"
  namespace  = var.namespace

  values = [yamlencode(local.helm_chart_input)]

  # external-dns and AWS ALB Ingress controller will turn the Ingress resources from the chart into AWS resources. These
  # are properly destroyed when the Ingress resource is destroyed. However, because of the asynchronous nature of
  # Kubernetes operations, there is a delay before the respective controllers delete the AWS resources. This can cause
  # problems when you are destroying related resources in quick succession (e.g the Route 53 Hosted Zone).
  # To handle this, we depend on a null resource that, when deleted, will sleep for 30 seconds, giving Kubernetes some
  # time to cull the resources before completing. Since this will depend on the null resource, the release will be
  # deleted before the null_resource is deleted and the sleep is triggered.
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

    ingress = {
      enabled     = var.expose_type != "cluster-internal"
      path        = "'${var.ingress_path}'"
      hosts       = var.create_route53_entry ? [var.domain_name] : []
      servicePort = "app"
      annotations = merge(
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
      )
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
          port   = "liveness"
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
          port   = "readiness"
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
  source           = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/load-balancer-access-logs?ref=v0.19.1"
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
# EMIT HELM CHART VALUES TO DISK FOR DEBUGGING
# ---------------------------------------------------------------------------------------------------------------------

resource "local_file" "debug_values" {
  count    = var.values_file_path != null ? 1 : 0
  content  = yamlencode(local.helm_chart_input)
  filename = var.values_file_path
}
