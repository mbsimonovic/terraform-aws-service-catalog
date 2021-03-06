# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH A MEMCACHED CLUSTER WITH AMAZON ELASTICACHE
# This module can be used to deploy a Memcached Cluster using Amazon ElastiCache.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.6, < 4.0"
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# LAUNCH THE ELASTICACHE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "memcached" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-cache.git//modules/memcached?ref=v0.17.0"

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
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/elasticache-memcached-alarms?ref=v0.32.0"
  create_resources = var.enable_cloudwatch_alarms

  cache_cluster_id     = module.memcached.cache_cluster_id
  cache_node_ids       = module.memcached.cache_node_ids
  num_cache_node_ids   = var.num_cache_nodes
  alarm_sns_topic_arns = var.alarms_sns_topic_arns
}
