output "cache_port" {
  value = module.redis.cache_port
}

output "cache_cluster_ids" {
  value = module.redis.cache_cluster_ids
}

output "cache_node_id" {
  value = module.redis.cache_node_id
}

output "primary_endpoint" {
  value = module.redis.primary_endpoint
}

output "configuration_endpoint" {
  value = module.redis.configuration_endpoint
}

output "read_endpoints" {
  value = module.redis.read_endpoints
}
