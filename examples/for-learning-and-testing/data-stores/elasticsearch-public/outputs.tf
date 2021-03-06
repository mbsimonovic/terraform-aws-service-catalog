output "cluster_arn" {
  description = "The ARN of the Elasticsearch cluster created by this module."
  value       = module.elasticsearch.cluster_arn
}

output "cluster_domain_id" {
  description = "The domain ID of the Elasticsearch cluster created by this module."
  value       = module.elasticsearch.cluster_domain_id
}

output "cluster_endpoint" {
  description = "The endpoint of the Elasticsearch cluster created by this module."
  value       = module.elasticsearch.cluster_endpoint
}

output "kibana_endpoint" {
  description = "Domain-specific endpoint for Kibana without https scheme."
  value       = module.elasticsearch.kibana_endpoint
}
