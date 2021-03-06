# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A KUBERNETES DEPLOYMENT AND SERVICE WITH AN INGRESS RESOURCE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
      version = ">= 2.6, < 4.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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
  version    = var.helm_chart_version
  namespace  = var.namespace

  values = [
    yamlencode(
      merge(
        local.helm_chart_input,
        var.override_chart_inputs,
      ),
    ),
  ]

  wait    = var.wait
  timeout = var.wait_timeout

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
      "alb.ingress.kubernetes.io/listen-ports"             = "[${join(",", local.ingress_listener_protocol_ports)}]"
      "alb.ingress.kubernetes.io/backend-protocol"         = var.ingress_backend_protocol
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "access_logs.s3.enabled=true,access_logs.s3.bucket=${module.alb_access_logs_bucket.s3_bucket_name},access_logs.s3.prefix=${local.access_logs_s3_prefix}"
    },
    (
      var.ingress_group != null
      ? {
        "alb.ingress.kubernetes.io/group.name" = var.ingress_group.name
      }
      : {}
    ),
    (
      # NOTE: can't use && because Terraform processes the conditional in one pass, and boolean operators are not short
      # circuit.
      var.ingress_group != null
      ? (
        var.ingress_group.priority != null
        ? {
          "alb.ingress.kubernetes.io/group.order" = tostring(var.ingress_group.priority)
        }
        : {}
      )
      : {}
    ),
    (
      var.ingress_configure_ssl_redirect
      ? {
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
      }
      : {}
    ),
    (
      var.domain_propagation_ttl != null
      ? {
        "external-dns.alpha.kubernetes.io/ttl" = tostring(var.domain_propagation_ttl)
      }
      : {}
    ),
    {
      "alb.ingress.kubernetes.io/certificate-arn" = join(",", var.alb_acm_certificate_arns),
      "alb.ingress.kubernetes.io/target-type"     = var.ingress_target_type
    },
    local.alb_health_check,
    var.ingress_annotations,
  )

  # Refer to the values.yaml file for helm-kubernetes-services/k8s-service for more information on the available input
  # parameters:
  # https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/charts/k8s-service/values.yaml
  # We use merge here to support optionally setting various input values (with fallback to chart defaults).
  helm_chart_input = merge(
    # Only enable the horizontalPodAutoscaler input value if it is set.
    (
      var.horizontal_pod_autoscaler == null
      ? {}
      : {
        horizontalPodAutoscaler = {
          enabled              = true
          minReplicas          = var.horizontal_pod_autoscaler.min_replicas
          maxReplicas          = var.horizontal_pod_autoscaler.max_replicas
          avgCpuUtilization    = var.horizontal_pod_autoscaler.avg_cpu_utilization
          avgMemoryUtilization = var.horizontal_pod_autoscaler.avg_mem_utilization
        }
      }
    ),
    # Only enable the terminationGracePeriodSeconds input value if it is set.
    (
      var.termination_grace_period_seconds == null
      ? {}
      : {
        terminationGracePeriodSeconds = var.termination_grace_period_seconds
      }
    ),
    {
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
      replicaCount     = var.desired_number_of_pods
      minPodsAvailable = var.min_number_of_pods_available

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
        create = (!var.service_account_exists) && var.service_account_name != ""

        name        = var.service_account_name
        namespace   = var.namespace
        annotations = local.iam_role == "" ? {} : { "eks.amazonaws.com/role-arn" = local.iam_role }
      }

      ingress = {
        enabled     = var.expose_type != "cluster-internal"
        path        = "'${var.ingress_path}'"
        pathType    = var.ingress_path_type
        hosts       = var.domain_name != null ? [var.domain_name] : []
        servicePort = "app"
        annotations = local.ingress_annotations
        # Only configure the redirect path if using ssl redirect
        additionalPathsHigherPriority = (
          # When in Ingress Group mode, we need to make sure to only define this once per group.
          var.ingress_configure_ssl_redirect && var.ingress_ssl_redirect_rule_already_exists == false
          ? [
            (
              var.ingress_ssl_redirect_rule_requires_path_type
              ? {
                path        = "/"
                pathType    = "Prefix"
                serviceName = "ssl-redirect"
                servicePort = "use-annotation"
              }
              : {
                path        = "/*"
                serviceName = "ssl-redirect"
                servicePort = "use-annotation"
              }
            )
          ]
          : []
        )
      }

      envVars      = var.env_vars
      configMaps   = local.configmaps
      secrets      = local.secrets
      scratchPaths = var.scratch_paths

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

      customResources = {
        enabled   = var.custom_resources != {}
        resources = var.custom_resources
      }
      sideCarContainers = var.sidecar_containers
    },
  )

  # We use interpolate a string here to construct a list of protocol port mappings for the listener, that can then be injected
  # into the input values. We do this instead of directly rendering the list because terraform does some type conversions
  # in the yaml encode process.
  ingress_listener_protocol_ports = [
    for protocol_ports in var.ingress_listener_protocol_ports :
    "{\"${protocol_ports["protocol"]}\": ${protocol_ports["port"]}}"
  ]
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE S3 BUCKETS FOR ALB LOGS
# When Ingress is enabled (expose_type = internal or external), we need to create S3 buckets to store the ALB access
# logs.
# ---------------------------------------------------------------------------------------------------------------------

module "alb_access_logs_bucket" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/logs/load-balancer-access-logs?ref=v0.32.0"
  create_resources = (
    var.expose_type != "cluster-internal"
    # Only create access logs if requested
    && var.ingress_access_logs_s3_bucket_already_exists == false
  )

  s3_bucket_name    = local.access_logs_s3_bucket_name
  s3_logging_prefix = local.access_logs_s3_prefix

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
  access_logs_s3_prefix      = var.ingress_access_logs_s3_prefix == null ? var.application_name : var.ingress_access_logs_s3_prefix
}


# ---------------------------------------------------------------------------------------------------------------------
# SET UP IAM ROLE FOR SERVICE ACCOUNT
# Set up IRSA if a service account and IAM role are configured.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "new_role" {
  count = var.iam_role_name != "" && var.iam_role_exists == false ? 1 : 0

  name               = var.iam_role_name
  assume_role_policy = module.service_account_assume_role_policy.assume_role_policy_json
}

module "service_account_assume_role_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-iam-role-assume-role-policy-for-service-account?ref=v0.50.1"

  eks_openid_connect_provider_arn = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_arn
  eks_openid_connect_provider_url = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_url
  namespaces                      = []
  service_accounts = [{
    name      = var.service_account_name
    namespace = var.namespace
  }]
}

resource "aws_iam_role_policy" "service_policy" {
  count = var.iam_role_name != "" && var.iam_role_exists == false && local.use_inline_policies ? 1 : 0

  name   = "${var.iam_role_name}Policy"
  role   = var.iam_role_name != "" && var.iam_role_exists == false ? aws_iam_role.new_role[0].id : data.aws_iam_role.existing_role[0].id
  policy = data.aws_iam_policy_document.service_policy[0].json
}

resource "aws_iam_policy" "service_policy" {
  count = var.iam_role_name != "" && var.iam_role_exists == false && var.use_managed_iam_policies ? 1 : 0

  name_prefix = "${var.iam_role_name}-policy"
  policy      = data.aws_iam_policy_document.service_policy[0].json
}

resource "aws_iam_role_policy_attachment" "service_policy" {
  count = var.iam_role_name != "" && var.iam_role_exists == false && var.use_managed_iam_policies ? 1 : 0

  role       = var.iam_role_name != "" && var.iam_role_exists == false ? aws_iam_role.new_role[0].id : data.aws_iam_role.existing_role[0].id
  policy_arn = aws_iam_policy.service_policy[0].arn
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

  name = var.iam_role_name
}

# ---------------------------------------------------------------------------------------------------------------------
# EMIT HELM CHART VALUES TO DISK FOR DEBUGGING
# ---------------------------------------------------------------------------------------------------------------------

resource "local_file" "debug_values" {
  count = var.values_file_path != null ? 1 : 0

  content         = yamlencode(local.helm_chart_input)
  filename        = var.values_file_path
  file_permission = "0644"
}
