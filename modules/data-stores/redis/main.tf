# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# LAUNCH A REDIS CLUSTER WITH AMAZON ELASTICACHE
# This module can be used to deploy a Redis Cluster using Amazon ElastiCache . It creates the following resources:
#
# - An replication group with 1 or more Redis cache clusters using ElastiCache.
# - CloudWatch alarms for monitoring performance issues with the Redis cache cluster.
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
# DEPLOY THE ELASTICACHE CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

module "redis" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-cache.git//modules/redis?ref=v0.17.0"

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

  snapshot_name = var.snapshot_name
  snapshot_arn  = var.snapshot_arn

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD CLOUDWATCH ALARMS FOR THE ELASTICACHE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "redis_alarms" {
  source           = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/elasticache-redis-alarms?ref=v0.32.0"
  create_resources = var.enable_cloudwatch_alarms

  cache_cluster_ids    = module.redis.cache_cluster_ids
  num_cluster_ids      = var.replication_group_size
  cache_node_id        = module.redis.cache_node_id
  alarm_sns_topic_arns = var.alarms_sns_topic_arns
}
