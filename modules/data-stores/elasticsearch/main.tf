# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH AN ELASTICSEARCH CLUSTER
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE TERRAFORM AND PROVIDER REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  # This module is now only being tested with Terraform 0.15.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.15.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elasticsearch_domain" "cluster" {
  depends_on = [aws_iam_service_linked_role.es]

  domain_name           = var.domain_name
  elasticsearch_version = var.elasticsearch_version
  tags                  = var.custom_tags

  cluster_config {
    # Data nodes
    instance_type  = var.instance_type
    instance_count = var.instance_count

    zone_awareness_enabled = var.zone_awareness_enabled

    # Dedicated master nodes
    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_type    = var.dedicated_master_type
    dedicated_master_count   = var.dedicated_master_count
  }

  dynamic "vpc_options" {
    for_each = (var.is_public ? [] : list(var.is_public))
    # Elasticsearch lets you specify 2 or 3 availability zones, if zone awareness is enabled.
    # NOTE: This will produce an error if the length of subnet_ids is less than var.availability_zone_count.
    content {
      subnet_ids = slice(
        var.subnet_ids,
        0,
        var.zone_awareness_enabled ? var.availability_zone_count : 1
      )
      security_group_ids = [aws_security_group.elasticsearch_cluster[0].id]
    }
  }

  access_policies = data.aws_iam_policy_document.elasticsearch_vpc_access_policy.json

  ebs_options {
    ebs_enabled = var.ebs_enabled
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = var.iops
  }

  encrypt_at_rest {
    enabled    = var.enable_encryption_at_rest
    kms_key_id = var.encryption_kms_key_id
  }

  snapshot_options {
    automated_snapshot_start_hour = var.automated_snapshot_start_hour
  }

  advanced_options = var.advanced_options

  node_to_node_encryption {
    enabled = var.enable_node_to_node_encryption
  }

  domain_endpoint_options {
    enforce_https = true

    # Valid values are "Policy-Min-TLS-1-0-2019-07" and "Policy-Min-TLS-1-2-2019-07"
    tls_security_policy = var.tls_security_policy
  }

  timeouts {
    update = var.update_timeout
  }
}

resource "aws_iam_service_linked_role" "es" {
  count            = var.create_service_linked_role ? 1 : 0
  aws_service_name = "es.amazonaws.com"
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE ACCESS POLICY AND SECURITY GROUPS FOR THE ELASTICSEARCH CLUSTER
# There are three tools for controlling access to this Elasticsearch cluster:
#
# 1. IAM. Limiting access to specific AWS Principals (e.g. IAM users and roles) is the most secure option.
#    However, this requires your Elasticsearch client to sign every request, which some clients don't support,
#    including Kibana. Therefore our default recommendation is not to use this option unless paired with VPC.
#    See:
#    https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-kibana.html#es-kibana-access
#    https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-createupdatedomains.html#es-createdomain-configure-access-policies
#
# 2. IP. You can limit access to specific CIDR blocks. This is especially useful if you want to expose your
#    Elasticsearch cluster publicly. See:
#    http://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/es-createupdatedomains.html#es-createdomain-configure-access-policies
#
# 3. VPC. Using the vpc_options in the aws_elasticsearch_domain resource, we configure the Elasticsearch cluster
#    to run in the private persistence subnets of your VPC and create security groups below to only allow access from
#    private app and private persistence subnets. Normal Elasticsearch clients (including Kibana) can now use the
#    cluster, but only from within your VPC (which means that to access Kibana, you'll have to connect via VPN).
#    Therefore the IAM policy below does not add any additional limitations on accessing the cluster, which we believe
#    provides a reasonable balance between security and usability.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "elasticsearch_vpc_access_policy" {
  statement {
    effect  = "Allow"
    actions = ["es:*"]
    principals {
      identifiers = var.iam_principal_arns
      type        = "AWS"
    }
    resources = ["arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}/*"]
  }
}

locals {
  https_port = 443
}

resource "aws_security_group" "elasticsearch_cluster" {
  count  = var.is_public ? 0 : 1
  name   = var.domain_name
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "allow_inbound_https_from_subnets" {
  count             = var.is_public == false ? (length(var.allow_connections_from_cidr_blocks) > 0 ? 1 : 0) : 0
  type              = "ingress"
  from_port         = local.https_port
  to_port           = local.https_port
  protocol          = "tcp"
  security_group_id = aws_security_group.elasticsearch_cluster[0].id
  cidr_blocks       = var.allow_connections_from_cidr_blocks
}

resource "aws_security_group_rule" "allow_inbound_https_from_security_group" {
  count                    = var.is_public == false ? length(var.allow_connections_from_security_groups) : 0
  type                     = "ingress"
  from_port                = local.https_port
  to_port                  = local.https_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticsearch_cluster[0].id
  source_security_group_id = tolist(var.allow_connections_from_security_groups)[count.index]
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "elasticsearch_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/elasticsearch-alarms?ref=v0.26.1"
  create_resources = var.enable_cloudwatch_alarms

  cluster_name   = var.domain_name
  aws_account_id = data.aws_caller_identity.current.account_id
  instance_type  = var.instance_type

  alarm_sns_topic_arns = var.alarm_sns_topic_arns
}

# ---------------------------------------------------------------------------------------------------------------------
# GET INFO ABOUT CURRENT USER/ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
