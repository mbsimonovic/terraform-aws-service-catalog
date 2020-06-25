output "cache_addresses" {
  description = "The list of DNS names of the Memcached nodes without the port appended."
  value       = module.memcached.cache_addresses
}

output "cache_cluster_id" {
  description = "The id of the ElastiCache Memcached cluster."
  value       = module.memcached.cache_cluster_id
}

output "cache_node_ids" {
  description = "The list of the AWS cache cluster node ids where each one represents a Memcached node."
  value       = module.memcached.cache_node_ids
}

output "configuration_endpoint" {
  description = "The configuration endpoint to allow host discovery."
  value       = module.memcached.configuration_endpoint
}

output "cache_port" {
  description = "The port number on which each of the cache nodes will accept connections (e.g. 11211)."
  value       = module.memcached.cache_port
}
