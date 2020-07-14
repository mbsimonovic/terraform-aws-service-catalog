output "cluster_arn" {
  value = aws_elasticsearch_domain.cluster.arn
}

output "cluster_domain_id" {
  value = aws_elasticsearch_domain.cluster.domain_id
}

output "cluster_endpoint" {
  value = aws_elasticsearch_domain.cluster.endpoint
}

output "cluster_security_group_id" {
  value = aws_security_group.elasticsearch_cluster.id
}
