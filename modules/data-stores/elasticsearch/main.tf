# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN ELASTICSEARCH CLUSTER
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE REMOTE STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.
  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "cluster" {
  domain_name           = var.domain_name
  elasticsearch_version = var.elasticsearch_version

  cluster_config {
    instance_type  = var.instance_type
    instance_count = var.instance_count

    zone_awareness_enabled = var.zone_awareness_enabled

    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_type    = var.dedicated_master_type
    dedicated_master_count   = var.dedicated_master_count
  }

  vpc_options {
    # Elasticsearch requires you to specify exactly 1 or 2 subnets, depending on whether zone awareness is enabled.
    subnet_ids = slice(
      var.subnet_ids,
      0,
      var.zone_awareness_enabled ? 2 : 1,
    )
    security_group_ids = [aws_security_group.elasticsearch_cluster.id]
  }

  access_policies = data.aws_iam_policy_document.elasticsearch_access_policy.json

  # EBS volumes are useful if your cluster nodes need more disk space than is available on the node itself. Note that
  # t2 nodes always require EBS volumes.
  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = var.iops
  }

  snapshot_options {
    automated_snapshot_start_hour = var.automated_snapshot_start_hour
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ACCESS POLICY AND SECURITY GROUPS FOR THE ELASTICSEARCH CLUSTER
# There are three tools for controlling access to this Elasticsearch cluster:
#
# 1. IAM. Limiting access to specific AWS Principals (e.g. IAM users and roles) is the most secure option.
#    However, this requires your Elasticsearch client to sign every request, which some clients don't support,
#    including Kibana. Therefore we have not enabled this option. If you'd like to enable it in the
#    future, see:
#    http://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-createupdatedomains.html#es-createdomain-configure-access-policies
#
# 2. IP. You can limit access to specific CIDR blocks. This is especially useful if you ever want to expose your
#    Elasticsearch cluster publicly. However, we're running our cluster in private subnets of a VPC, so there's no
#    need to do this. If you need it in the future, see:
#    http://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-createupdatedomains.html#es-createdomain-configure-access-policies
#
# 3. VPC. Using the vpc_options in the aws_elasticsearch_domain resource, we configure the Elasticsearch cluster
#    to run in the private persistence subnets of your VPC and create security groups below to only allow access from
#    private app and private persistence subnets. Normal Elasticsearch clients (including Kibana) can now use the
#    cluster, but only from within your VPC (which means that to access Kibana, you'll have to connect via VPN).
#    Therefore the IAM policy below does not add any additional limitations on accessing the cluster, which we believe
#    provides a reasonable balance between security and usability.
# ---------------------------------------------------------------------------------------------------------------------

# TODO: why is this needed?
data "aws_iam_policy_document" "elasticsearch_access_policy" {
  statement {
    effect  = "Allow"
    actions = ["es:*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    resources = ["arn:aws:es:${var.aws_region}:${var.aws_account_id}:domain/${var.domain_name}/*"]
  }
}

locals {
  http_port  = 80
  https_port = 443
}

resource "aws_security_group" "elasticsearch_cluster" {
  name   = var.domain_name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.elasticsearch_cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all_inbound_http_from_app_and_persistence_subnets" {
  count             = length(var.private_app_subnet_cidr_blocks) > 0 || length(var.private_persistence_subnet_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_cluster.id
  cidr_blocks = concat(
    var.private_app_subnet_cidr_blocks,
    var.private_persistence_subnet_cidr_blocks,
  )
}

resource "aws_security_group_rule" "allow_all_inbound_https_from_app_and_persistence_subnets" {
  count             = length(var.private_app_subnet_cidr_blocks) > 0 || length(var.private_persistence_subnet_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = local.https_port
  to_port           = local.https_port
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_cluster.id
  cidr_blocks = concat(
    var.private_app_subnet_cidr_blocks,
    var.private_persistence_subnet_cidr_blocks,
  )
}

resource "aws_security_group_rule" "allow_all_inbound_http_from_bastion_host" {
  count                    = var.allow_connections_from_bastion_host ? 1 : 0
  type                     = "ingress"
  from_port                = local.http_port
  to_port                  = local.http_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticsearch_cluster.id
  source_security_group_id = var.bastion_host_security_group_id
}

resource "aws_security_group_rule" "allow_all_inbound_https_from_bastion_host" {
  count                    = var.allow_connections_from_bastion_host ? 1 : 0
  type                     = "ingress"
  from_port                = local.https_port
  to_port                  = local.https_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticsearch_cluster.id
  source_security_group_id = var.bastion_host_security_group_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "elasticsearch_alarms" {
  source = "git::git@github.com:gruntwork-io/module-aws-monitoring.git//modules/alarms/elasticsearch-alarms?ref=v0.21.2"

  cluster_name   = aws_elasticsearch_domain.cluster.domain_name
  aws_account_id = var.aws_account_id
  instance_type  = var.instance_type

  # TODO: should I allow inputting only a single arn?
  # alarm_sns_topic_arns = [var.alarm_sns_topic_arn]
  alarm_sns_topic_arns = var.alarm_sns_topic_arns
}
