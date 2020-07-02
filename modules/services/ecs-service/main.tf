# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN ECS SERVICE
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  # The AWS region in which all resources will be created
  region = var.aws_region

  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "{{ .AWSProviderVersion }}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = [var.aws_account_id]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}

  # Only allow this Terraform version. Note that if you upgrade to a newer version, Terraform won't allow you to use an
  # older version, so when you upgrade, you should upgrade everyone on your team and your CI servers all at once.
  required_version = "{{ .TerraformRequiredVersion }}"
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

module "ecs_service" {
  source = "git::git@github.com:gruntwork-io/module-ecs.git//modules/ecs-service?ref={{ .ModuleEcsVersion }}"

  service_name     = var.service_name
  ecs_cluster_arn  = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_arn
  environment_name = var.vpc_name

{{- if .ConfigureCanaryDeployment }}

  ecs_task_container_definitions = data.template_file.container_definition.0.rendered
  desired_number_of_tasks        = var.desired_number_of_tasks

  ecs_task_definition_canary            = data.template_file.container_definition.1.rendered
  desired_number_of_canary_tasks_to_run = var.desired_number_of_canary_tasks
{{- else }}

  ecs_task_container_definitions = data.template_file.container_definition.rendered
  desired_number_of_tasks        = var.desired_number_of_tasks
{{- end -}}

{{- if .IncludeAutoScalingExample }}

  # Tell the ECS Service that we are using auto scaling, so the desired_number_of_tasks setting is only used to control
  # the initial number of Tasks, and auto scaling is used to determine the size after that.
  use_auto_scaling = true
  min_number_of_tasks = var.min_number_of_tasks
  max_number_of_tasks = var.max_number_of_tasks
{{- end }}

  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
}

{{- if .ExposeEcsServiceToOtherEcsNodes }}

# Update the ECS Node Security Group to allow the ECS Service to be accessed directly from an ECS Node (versus only from the ELB).
resource "aws_security_group_rule" "custom_permissions" {
  count = var.num_port_mappings

  type      = "ingress"
  from_port = element(values(var.port_mappings), count.index)
  to_port   = element(values(var.port_mappings), count.index)
  protocol  = "tcp"

  source_security_group_id = data.terraform_remote_state.ecs_cluster.outputs.ecs_instance_security_group_id
  security_group_id        = data.terraform_remote_state.ecs_cluster.outputs.ecs_instance_security_group_id
}
{{ end -}}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE CONTAINER DEFINITION THAT SPECIFIES WHAT DOCKER CONTAINERS TO RUN AND THE RESOURCES THEY NEED
# ---------------------------------------------------------------------------------------------------------------------

# Create the "container" portion of the ECS Task definition.
data "template_file" "container_definition" {
{{- if .ConfigureCanaryDeployment }}
  # We create two container definitions: the first one is for normal deployment and the second one is for canary deployment
  count = 2
{{- end }}

  template = file("${path.module}/container-definition/container-definition.json")

  vars = {
    image          = var.image
    container_name = var.service_name
    version        = {{ if .ConfigureCanaryDeployment }}[var.image_version, var.canary_version][count.index]{{ else }}var.image_version{{ end }}
    cpu            = var.cpu
    memory         = var.memory
    vpc_name       = var.vpc_name
    port_mappings  = "[${join(",", data.template_file.port_mappings.*.rendered)}]"
    env_vars       = "[${join(",", data.template_file.all_env_vars.*.rendered)}]"
  {{- if .UseCustomDockerRunCommand }}
    command        = join(",", formatlist("\"%s\"", var.custom_docker_command))
  {{- end }}
  }
}

# Convert the maps of ports to the container definition JSON format.
data "template_file" "port_mappings" {
  count = length(var.ecs_node_port_mappings)
  template = <<EOF
{
  "containerPort": ${var.ecs_node_port_mappings[element(keys(var.ecs_node_port_mappings), count.index)]},
  "hostPort": ${element(keys(var.ecs_node_port_mappings), count.index)},
  "protocol": "tcp"
}
EOF
}

locals {
  # Create default map of env vars in the JSON format used by ECS container definitions.
  #
  # NOTE: if you add a default env var, make sure to update the count in data.template_file.all_env_vars!!!
  default_env_vars = map(
    var.vpc_env_var_name, var.vpc_name,
    var.aws_region_env_var_name, var.aws_region
    {{- if .IncludeDatabaseUrl }},
    var.db_url_env_var_name, data.terraform_remote_state.db.outputs.primary_endpoint
    {{- end }}
  )

  # Merge the default env vars with any extra env vars passed in by the user into a single map
  all_env_vars = merge(local.default_env_vars, var.extra_env_vars)
}

# Convert the env vars into a JSON format used by ECS container definitions.
data "template_file" "all_env_vars" {
  # Terraform does not allow us to depend on modules, data sources, or any other dynamic data in the count parameter,
  # so we have to manually add the number of env vars in var.extra_env_vars and local.default_env_vars.
  count = var.num_extra_env_vars + {{ if .IncludeDatabaseUrl }}3{{ else }}2{{ end }}}
  template = <<EOF
{
  "name": "${element(keys(local.all_env_vars), count.index)}",
  "value": "${lookup(local.all_env_vars, element(keys(local.all_env_vars), count.index))}"
}
EOF
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM PERMISSIONS FOR THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------

# Give this ECS Service access to the KMS Master Key so it can use it to decrypt secrets in config files.
resource "aws_iam_role_policy" "access_kms_master_key" {
  name = "access-kms-master-key"
  role = module.ecs_service.ecs_task_iam_role_name
  policy = data.aws_iam_policy_document.access_kms_master_key.json
}

# Create an IAM Policy for acessing the KMS Master Key
data "aws_iam_policy_document" "access_kms_master_key" {
  statement {
    effect = "Allow"
    actions = ["kms:Decrypt"]
    resources = [data.terraform_remote_state.kms_master_key.outputs.key_arn]
  }
}
{{- if .InstallCloudWatchMonitoring }}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS TO ALERT OPERATORS TO IMPORTANT ISSUES
# ---------------------------------------------------------------------------------------------------------------------

# Add CloudWatch Alarms that go off if the ECS Service's CPU or Memory usage gets too high.
module "ecs_service_cpu_memory_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/ecs-service-alarms?ref={{ .ModuleAwsMonitoringVersion }}"

  ecs_service_name     = var.service_name
  ecs_cluster_name     = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name
  alarm_sns_topic_arns = [data.terraform_remote_state.sns_region.outputs.arn]

  high_cpu_utilization_threshold    = var.high_cpu_utilization_threshold
  high_cpu_utilization_period       = var.high_cpu_utilization_period
  high_memory_utilization_threshold = var.high_memory_utilization_threshold
  high_memory_utilization_period    = var.high_memory_utilization_period
}

module "metric_widget_ecs_service_cpu_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref={{ .ModuleAwsMonitoringVersion }}"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} CPUUtilization"

  metrics = [
    ["AWS/ECS", "CPUUtilization", "ClusterName", data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name, "ServiceName", var.service_name],
  ]
}

module "metric_widget_ecs_service_memory_usage" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-dashboard-metric-widget?ref={{ .ModuleAwsMonitoringVersion }}"

  period = 60
  stat   = "Average"
  title  = "${title(var.service_name)} MemoryUtilization"

  metrics = [
    ["AWS/ECS", "MemoryUtilization", "ClusterName", data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name, "ServiceName", var.service_name],
  ]
}
{{- end }}

{{- if .IncludeAutoScalingExample }}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE AUTO SCALING OF THIS ECS SERVICE'S CONTAINERS
# Note that Auto Scaling of the ECS Cluster's EC2 Instances is handled spearately.
# ---------------------------------------------------------------------------------------------------------------------

# Create an Auto Scaling Policy to scale the number of ECS Tasks up in response to load.
resource "aws_appautoscaling_policy" "scale_out" {
  name        = "${var.service_name}-scale-out"
  resource_id = "service/${data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name}/${var.service_name}"

  adjustment_type         = "ChangeInCapacity"
  cooldown                = 60
  metric_aggregation_type = "Average"

  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment = 1
  }

  # NOTE: due to a Terraform bug, this depends_on does not actually help, and it's possible the auto scaling target has
  # not been created when Terraform tries to create this auto scaling policy. As a result, you get an error along the
  # lines of "Error putting scaling policy: ObjectNotFoundException: No scalable target registered for service
  # namespace..." Wait a few seconds, re-run `terraform apply`, and the erorr should go away. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10737
  depends_on = [module.ecs_service]
}

# Create an Auto Scaling Policy to scale the number of ECS Tasks down in response to load.
resource "aws_appautoscaling_policy" "scale_in" {
  name        = "${var.service_name}-scale-in"
  resource_id = "service/${data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name}/${var.service_name}"

  adjustment_type = "ChangeInCapacity"
  cooldown = 60
  metric_aggregation_type = "Average"

  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment = -1
  }

  # NOTE: due to a Terraform bug, this depends_on does not actually help, and it's possible the auto scaling target has
  # not been created when Terraform tries to create this auto scaling policy. As a result, you get an error along the
  # lines of "Error putting scaling policy: ObjectNotFoundException: No scalable target registered for service
  # namespace..." Wait a few seconds, re-run `terraform apply`, and the erorr should go away. For more info, see:
  # https://github.com/hashicorp/terraform/issues/10737
  depends_on = [module.ecs_service]
}

# Create a CloudWatch Alarm to trigger our Auto Scaling Policies if CPU Utilization gets too high.
resource "aws_cloudwatch_metric_alarm" "high_cpu_usage" {
  alarm_name        = "${var.service_name}-high-cpu-usage"
  alarm_description = "An alarm that triggers auto scaling if the CPU usage for service ${var.service_name} gets too high"
  namespace = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions {
    ClusterName = "${data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name}"
    ServiceName = "${var.service_name}"
  }
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  period = "60"
  statistic = "Average"
  threshold = "90"
  unit = "Percent"
  alarm_actions = [aws_appautoscaling_policy.scale_out.arn]
}

# Create a CloudWatch Alarm to trigger our Auto Scaling Policies if CPU Utilization gets sufficiently low.
resource "aws_cloudwatch_metric_alarm" "low_cpu_usage" {
  alarm_name = "${var.service_name}-low-cpu-usage"
  alarm_description = "An alarm that triggers auto scaling if the CPU usage for service ${var.service_name} gets too low"
  namespace = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions {
    ClusterName = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_name
    ServiceName = var.service_name
  }
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  period = "60"
  statistic = "Average"
  threshold = "70"
  unit = "Percent"
  alarm_actions = [aws_appautoscaling_policy.scale_in.arn]
}
{{- end }}

# ---------------------------------------------------------------------------------------------------------------------
# PULL DATA FROM OTHER TERRAFORM TEMPLATES USING TERRAFORM REMOTE STATE
# These templates use Terraform remote state to access data from a number of other Terraform templates, all of which
# store their state in S3 buckets.
# ---------------------------------------------------------------------------------------------------------------------

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "${var.aws_region}/${var.vpc_name}/vpc/terraform.tfstate"
  }
}

data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "${var.aws_region}/${var.vpc_name}/services/ecs-cluster/terraform.tfstate"
  }
}

{{- if .InstallCloudWatchMonitoring }}

data "terraform_remote_state" "sns_region" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "${var.aws_region}/_global/sns-topics/terraform.tfstate"
  }
}

# Route 53 health check alarms can only go to the us-east-1 region
data "terraform_remote_state" "sns_us_east_1" {
  backend = "s3"
  config = {
    region = "${var.terraform_state_aws_region}"
    bucket = "${var.terraform_state_s3_bucket}"
    key = "us-east-1/_global/sns-topics/terraform.tfstate"
  }
}
{{- end }}

data "terraform_remote_state" "kms_master_key" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "${var.aws_region}/{{ if .KmsKeyIsGlobal }}_global{{ else }}${var.vpc_name}{{ end }}/${var.terraform_state_kms_master_key}/terraform.tfstate"
  }
}

{{- if .IncludeDatabaseUrl }}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    region = var.terraform_state_aws_region
    bucket = var.terraform_state_s3_bucket
    key    = "${var.aws_region}/${var.vpc_name}/${var.db_remote_state_path}"
  }
}
{{- end }}
