# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A SERVICE IN AN AUTO SCALING GROUP WITH AN ALB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  required_providers {
    aws = "~> 2.6"
  }

  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

module "asg" {
  source = "git::git@github.com:gruntwork-io/module-asg.git//modules/asg-rolling-deploy?ref=v0.8.7"

  aws_region                = data.aws_region.current.name
  launch_configuration_name = aws_launch_configuration.launch_configuration.name
  vpc_subnet_ids            = var.subnet_ids
  target_group_arns         = [aws_alb_target_group.service.arn]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  min_elb_capacity = var.min_elb_capacity
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "launch_configuration" {
  name_prefix          = "${var.name}-"
  image_id             = var.ami
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  key_name             = var.keypair_name
  security_groups      = [aws_security_group.lc_security_group.id]
  user_data            = var.user_data

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE SECURITY GROUP THAT'S APPLIED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "lc_security_group" {
  name        = "${var.name}-lc"
  description = "Security group for the ${var.name} launch configuration"
  vpc_id      = var.vpc_id

  # Outbound everything
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTP from the ALB
  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = var.alb_security_groups
  }

  # Inbound SSH from the bastion host
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = var.vpn_security_group_ids
  }

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE AND POLICY THAT ARE ATTACHED TO EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.name
  role = aws_iam_role.instance_role.name

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "instance_role" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json

  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE THIS SERVICE ACCESS TO THE KMS MASTER KEY SO IT CAN USE IT TO DECRYPT SECRETS IN CONFIG FILES
# ---------------------------------------------------------------------------------------------------------------------


// TODO REMOVE
resource "aws_iam_policy" "access_kms_master_key" {
  name   = "access-kms-master-key-${var.name}"
  policy = data.aws_iam_policy_document.access_kms_master_key.json
}

data "aws_iam_policy_document" "access_kms_master_key" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = var.alarms_sns_topic_arn
  }
}

resource "aws_iam_policy_attachment" "attach_access_kms_master_key" {
  name       = "attach-access-kms-master-key-${var.name}" // TODO another kms key, remove
  roles      = [aws_iam_role.instance_role.name]
  policy_arn = aws_iam_policy.access_kms_master_key.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE SSH-GRUNT PERMISSIONS TO TALK TO IAM
# We add an IAM policy to each EC2 Instance that allows ssh-grunt to make API calls to IAM to fetch IAM user and group
# data.
# ---------------------------------------------------------------------------------------------------------------------

module "iam_policies" {
  source = "git::git@github.com:gruntwork-io/module-security.git//modules/iam-policies?ref=v0.32.0"

  aws_account_id = data.aws_caller_identity.current.account_id

  # ssh-grunt is an automated app, so we can't use MFA with it
  iam_policy_should_require_mfa   = false
  trust_policy_should_require_mfa = false

  # Since our IAM users are defined in a separate AWS account, we need to give ssh-grunt permission to make API calls to
  # that account.
  allow_access_to_other_account_arns = var.iam_users_defined_in_separate_account ?  { ssh_grunt = [var.external_account_ssh_grunt_role_arn] } : {}
}

resource "aws_iam_role_policy" "ssh_grunt_permissions" {
  name   = "ssh-grunt-permissions"
  role   = aws_iam_role.instance_role.id
  policy = var.iam_users_defined_in_separate_account ? module.iam_policies.allow_access_to_other_accounts[0] : module.iam_policies.ssh_grunt_permissions
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALB TARGET GROUP AND LISTENER RULE TO RECEIVE TRAFFIC FROM THE ALB FOR CERTAIN PATHS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_target_group" "service" {
  name     = var.name
  port     = var.server_port
  protocol = var.health_check_protocol
  vpc_id   = var.vpc_id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 10
    protocol            = var.health_check_protocol
    port                = "traffic-port"
    path                = var.health_check_path
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ROUTING RULES FOR THIS SERVICE
# Below, we configure the ALB to send requests that come in on certain ports (the listener_arn) and certain paths or
# domain names (the condition block) to the Target Group that contains this ASG service.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_alb_listener_rule" "paths_to_route_to_this_service" {
  count = length(var.alb_listener_rule_configs)

  listener_arn = var.alb_listener_arn
  priority     = var.alb_listener_rule_configs[count.index]["priority"]

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = [var.alb_listener_rule_configs[count.index]["path"]]
    }
  }
}

# ------------------------------------------------------------------------------
# CREATE A DNS RECORD USING ROUTE 53
# ------------------------------------------------------------------------------

resource "aws_route53_record" "service" {
  count = var.create_route53_entry ? 1 : 0

  zone_id = var.hosted_zone_id

  name = var.domain_name
  type = "A"

  alias {
    name                   = var.original_alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS READING AND WRITING CLOUDWATCH METRICS
# ---------------------------------------------------------------------------------------------------------------------

module "cloudwatch_metrics" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/metrics/cloudwatch-custom-metrics-iam-policy?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_metrics

  name_prefix = var.name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_metrics_policy" {
  count = var.enable_cloudwatch_metrics ? 1 : 0

  name       = "attach-cloudwatch-metrics-policy"
  roles      = [aws_iam_role.instance_role.id]
  policy_arn = module.cloudwatch_metrics.cloudwatch_metrics_policy_arn
}

# ------------------------------------------------------------------------------
# ADD IAM POLICY THAT ALLOWS CLOUDWATCH LOG AGGREGATION
# ------------------------------------------------------------------------------

module "cloudwatch_log_aggregation" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/logs/cloudwatch-log-aggregation-iam-policy?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_log_aggregation

  name_prefix = var.name
}

resource "aws_iam_policy_attachment" "attach_cloudwatch_log_aggregation_policy" {
  count = var.enable_cloudwatch_log_aggregation ? 1 : 0

  name = "attach-cloudwatch-log-aggregation-policy"

  roles      = [aws_iam_role.instance_role.id]
  policy_arn = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS THAT GO OFF IF THE SERVICE'S CPU, MEMORY, OR DISK USAGE GET TOO HIGH
# ---------------------------------------------------------------------------------------------------------------------

module "asg_high_cpu_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-cpu-alarms?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_alarms

  asg_names            = [module.asg.asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

module "asg_high_memory_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-memory-alarms?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_alarms

  asg_names            = [module.asg.asg_name]
  num_asg_names        = 1
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

module "asg_high_disk_usage_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/asg-disk-alarms?ref=v0.21.2"

  create_resources = var.enable_cloudwatch_alarms

  asg_names            = [module.asg.asg_name]
  num_asg_names        = 1
  file_system          = "/dev/xvda1"
  mount_path           = "/"
  alarm_sns_topic_arns = var.alarms_sns_topic_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD A ROUTE 53 HEALTHCHECK THAT TRIGGERS AN ALARM IF THE DOMAIN NAME IS UNRESPONSIVE
# Note: Route 53 sends all of its CloudWatch metrics to us-east-1, so the health check, alarm, and SNS topic must ALL
# live in us-east-1 as well! See https://github.com/hashicorp/terraform/issues/7371 for details.
# ---------------------------------------------------------------------------------------------------------------------

module "route53_health_check" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/route53-health-check-alarms?ref=v0.21.2"

  create_resources = var.enable_route53_health_check

  domain                         = var.domain_name
  alarm_sns_topic_arns_us_east_1 = [] // ?? [data.terraform_remote_state.sns_us_east_1.outputs.arn]

  path = var.health_check_path
  type = var.health_check_protocol
  port = var.health_check_protocol == "HTTP" ? 80 : 443

  failure_threshold = 2
  request_interval  = 30
}

# ---------------------------------------------------------------------------------------------------------------------
# PULL DATA FROM OTHER TERRAFORM TEMPLATES USING TERRAFORM REMOTE STATE
# These templates use Terraform remote state to access data from a number of other Terraform templates, all of which
# store their state in S3 buckets.
# ---------------------------------------------------------------------------------------------------------------------
//
//data "terraform_remote_state" "vpc" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/vpc/terraform.tfstate"
//  }
//}
//
//data "terraform_remote_state" "vpn" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//        // TODO TEST THIS INTERPOLATION
//    key    = "${var.aws_region}/${var.mgmt_vpc_name}/${var.using_open_vpn ? "openvpn-server" : "bastion-host"}/terraform.tfstate"
//  }
//}
//data "terraform_remote_state" "bastion_host" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.mgmt_vpc_name}/bastion-host/terraform.tfstate"
//  }
//}

//data "terraform_remote_state" "alb" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/networking/${var.is_internal_alb ? "alb-internal" : "alb-public"}/terraform.tfstate"
//  }
//}
//
//{{- if .IncludeInternalAlbUrl }}
//
//data "terraform_remote_state" "alb_internal" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/networking/alb-internal/terraform.tfstate"
//  }
//}
//{{- end }}
//
//{{- if .InstallCloudWatchMonitoring }}
//
//data "terraform_remote_state" "sns_region" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/_global/sns-topics/terraform.tfstate"
//  }
//}
//
//# Route 53 health check alarms can only go to the us-east-1 region
//data "terraform_remote_state" "sns_us_east_1" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "us-east-1/_global/sns-topics/terraform.tfstate"
//  }
//}
//{{- end }}
//
//{{- if .IncludeDatabaseUrl }}
//
//data "terraform_remote_state" "db" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/${var.db_remote_state_path}"
//  }
//}
//{{- end }}
//
//{{- if .IncludeRedisUrl }}
//
//data "terraform_remote_state" "redis" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/${var.redis_remote_state_path}"
//  }
//}
//{{- end }}
//
//{{- if .IncludeMemcachedUrl }}
//
//data "terraform_remote_state" "memcached" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/${var.memcached_remote_state_path}"
//  }
//}
//{{- end }}
//
//{{- if .IncludeMongoDbUrl }}
//
//data "terraform_remote_state" "mongodb" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/${var.mongodb_remote_state_path}"
//  }
//}
//{{- end }}
//
//{{- if .IncludeElasticsearchUrl }}
//
//data "terraform_remote_state" "elasticsearch" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/${var.elasticsearch_remote_state_path}"
//  }
//}
//{{- end }}
//
//data "terraform_remote_state" "kms_master_key" {
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/{{ if .KmsKeyIsGlobal }}_global{{ else }}${var.vpc_name}{{ end }}/${var.terraform_state_kms_master_key}/terraform.tfstate"
//  }
//}
//
//data "terraform_remote_state" "route53_private" {
//  count = var.create_route53_entry && var.is_internal_alb ? 1 : 0
//
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "${var.aws_region}/${var.vpc_name}/networking/route53-private/terraform.tfstate"
//  }
//}
//
//data "terraform_remote_state" "route53_public" {
//  count = var.create_route53_entry && (! var.is_internal_alb) ? 1 : 0
//
//  backend = "s3"
//  config = {
//    region = var.terraform_state_aws_region
//    bucket = var.terraform_state_s3_bucket
//    key    = "_global/route53-public/terraform.tfstate"
//  }
//}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DATA SOURCES
# These resources must already exist.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Grab the current region as a data source so the operator only needs to set it on the provider
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
