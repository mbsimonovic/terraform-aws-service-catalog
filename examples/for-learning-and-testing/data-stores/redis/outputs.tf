output "cache_port" {
  description = "The port number on which each of the cache nodes will accept connections (e.g. 6379)."
  value       = module.redis.cache_port
}

output "cache_cluster_ids" {
  description = "The list of AWS cache cluster ids where each one represents a Redis node."
  value       = module.redis.cache_cluster_ids
}

output "cache_node_id" {
  description = "The id of the ElastiCache node. Note: Each Redis cache cluster has only one node and its id is always 0001."
  value       = module.redis.cache_node_id
}

# The following outputs are related to the endpoints for accessing the Redis cluster.
# For more information refer to: https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Endpoints.html
output "primary_endpoint" {
  description = "The primary endpoint is a DNS name that always resolves to the primary node in the Redis cluster."
  value       = module.redis.primary_endpoint
}

output "configuration_endpoint" {
  description = "When cluster mode is enabled, use this endpoint for all operations. Redis will automatically determine which of the cluster's node to access."
  value       = module.redis.configuration_endpoint
}

output "reader_endpoint" {
  description = "When cluster mode is disabled, use this endpoint for all read operations."
  value       = module.redis.reader_endpoint
}
