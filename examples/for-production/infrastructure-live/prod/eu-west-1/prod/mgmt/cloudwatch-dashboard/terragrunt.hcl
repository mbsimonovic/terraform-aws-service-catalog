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
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard?ref=v0.20.0"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# Pull in outputs from these modules to compute inputs. These modules will also be added to the dependency list for
# xxx-all commands.
# For each dependency, we also set mock outputs that can be used for running `validate-all` without having to apply the
# underlying modules. Note that we only use this path for validation of the module, as using mock values for `plan-all`
# can lead to unintended consequences.
dependency "aurora" {
  config_path = "../../data-stores/aurora"

  mock_outputs = {
    metric_widget_aurora_cpu_usage      = {}
    metric_widget_aurora_memory         = {}
    metric_widget_aurora_disk_space     = {}
    metric_widget_aurora_db_connections = {}
    metric_widget_aurora_read_latency   = {}
    metric_widget_aurora_write_latency  = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependency "rds" {
  config_path = "../../data-stores/rds"

  mock_outputs = {
    metric_widget_rds_cpu_usage      = {}
    metric_widget_rds_memory         = {}
    metric_widget_rds_disk_space     = {}
    metric_widget_rds_db_connections = {}
    metric_widget_rds_read_latency   = {}
    metric_widget_rds_write_latency  = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

dependency "eks_cluster" {
  config_path = "../../services/eks-cluster"

  mock_outputs = {
    metric_widget_worker_cpu_usage    = {}
    metric_widget_worker_memory_usage = {}
    metric_widget_worker_disk_usage   = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

# Locals are named constants that are reusable within the configuration.
locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  dashboards = {
    # Overview dashboard with core metrics for all services (data stores and EKS cluster)
    "${local.account_vars.locals.account_name}-overview" = [
      dependency.aurora.outputs.metric_widget_aurora_cpu_usage,
      dependency.aurora.outputs.metric_widget_aurora_memory,
      dependency.aurora.outputs.metric_widget_aurora_disk_space,
      dependency.rds.outputs.metric_widget_rds_cpu_usage,
      dependency.rds.outputs.metric_widget_rds_memory,
      dependency.rds.outputs.metric_widget_rds_disk_space,
      dependency.eks_cluster.outputs.metric_widget_worker_cpu_usage,
      dependency.eks_cluster.outputs.metric_widget_worker_memory_usage,
      dependency.eks_cluster.outputs.metric_widget_worker_disk_usage,
    ]

    # Aurora DB dashboard
    "${local.account_vars.locals.account_name}-aurora-dashboard" = [
      dependency.aurora.outputs.metric_widget_aurora_cpu_usage,
      dependency.aurora.outputs.metric_widget_aurora_memory,
      dependency.aurora.outputs.metric_widget_aurora_disk_space,
      dependency.aurora.outputs.metric_widget_aurora_db_connections,
      dependency.aurora.outputs.metric_widget_aurora_read_latency,
      dependency.aurora.outputs.metric_widget_aurora_write_latency,
    ]

    # RDS DB dashboard
    "${local.account_vars.locals.account_name}-rds-dashboard" = [
      dependency.rds.outputs.metric_widget_rds_cpu_usage,
      dependency.rds.outputs.metric_widget_rds_memory,
      dependency.rds.outputs.metric_widget_rds_disk_space,
      dependency.rds.outputs.metric_widget_rds_db_connections,
      dependency.rds.outputs.metric_widget_rds_read_latency,
      dependency.rds.outputs.metric_widget_rds_write_latency,
    ]
  }
}
