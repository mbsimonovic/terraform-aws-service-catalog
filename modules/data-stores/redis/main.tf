# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH A REDIS CLUSTER WITH AMAZON ELASTICACHE
# This module can be used to deploy a Redis Cluster using Amazon ElastiCache . It creates the following resources:
#
# - An replication group with 1 or more Redis cache clusters using ElastiCache.
# - CloudWatch alarms for monitoring performance issues with the Redis cache cluster.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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


# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY THE ELASTICACHE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "redis" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-cache.git//modules/redis?ref=v0.13.0"

  name = var.name

  instance_type          = var.instance_type
  replication_group_size = var.replication_group_size
  redis_version          = var.redis_version
  port                   = var.port

  vpc_id                                 = var.vpc_id
  subnet_ids                             = var.subnet_ids
  allow_connections_from_cidr_blocks     = var.allow_connections_from_cidr_blocks
  allow_connections_from_security_groups = var.allow_connections_from_security_groups

  enable_automatic_failover = var.enable_automatic_failover
  enable_multi_az           = var.enable_multi_az

  parameter_group_name     = var.parameter_group_name
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  apply_immediately        = var.apply_immediately
  maintenance_window       = var.maintenance_window

  sns_topic_for_notifications = var.sns_topic_for_notifications

  enable_at_rest_encryption = var.enable_at_rest_encryption
  enable_transit_encryption = var.enable_transit_encryption
  cluster_mode              = var.cluster_mode
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE ELASTICACHE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "redis_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/elasticache-redis-alarms?ref=v0.26.1"
  create_resources = var.enable_cloudwatch_alarms

  cache_cluster_ids    = module.redis.cache_cluster_ids
  num_cluster_ids      = var.replication_group_size
  cache_node_id        = module.redis.cache_node_id
  alarm_sns_topic_arns = var.alarms_sns_topic_arns
}
