output "cluster_arn" {
  description = "The ARN of the Elasticsearch cluster created by this module."
  value       = aws_elasticsearch_domain.cluster.arn
}

output "cluster_domain_id" {
  description = "The domain ID of the Elasticsearch cluster created by this module."
  value       = aws_elasticsearch_domain.cluster.domain_id
}

output "cluster_endpoint" {
  description = "The endpoint of the Elasticsearch cluster created by this module."
  value       = aws_elasticsearch_domain.cluster.endpoint
}

output "cluster_security_group_id" {
  description = "If the domain was created inside a VPC, the ID of the security group created by this module for securing the Elasticsearch cluster."
  value       = length(aws_security_group.elasticsearch_cluster) > 0 ? aws_security_group.elasticsearch_cluster[0].id : null
}

output "kibana_endpoint" {
  description = "Domain-specific endpoint for Kibana without https scheme."
  value       = aws_elasticsearch_domain.cluster.kibana_endpoint
}
