# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH A MEMCACHED CLUSTER WITH AMAZON ELASTICACHE
# This module can be used to deploy a Memcached Cluster using Amazon ElastiCache.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 0.13.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 0.13.x code.
  required_version = ">= 0.12.26"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6"
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# LAUNCH THE ELASTICACHE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "memcached" {
  source = "git::git@github.com:gruntwork-io/module-cache.git//modules/memcached?ref=v0.10.1"

  name = var.name

  instance_type     = var.instance_type
  num_cache_nodes   = var.num_cache_nodes
  memcached_version = var.memcached_version
  port              = var.port

  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  az_mode = var.az_mode

  apply_immediately  = var.apply_immediately
  maintenance_window = var.maintenance_window
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE ELASTICACHE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "memcached_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/elasticache-memcached-alarms?ref=v0.23.3"
  create_resources = var.enable_cloudwatch_alarms

  cache_cluster_id     = module.memcached.cache_cluster_id
  cache_node_ids       = module.memcached.cache_node_ids
  num_cache_node_ids   = var.num_cache_nodes
  alarm_sns_topic_arns = var.alarms_sns_topic_arns
}
