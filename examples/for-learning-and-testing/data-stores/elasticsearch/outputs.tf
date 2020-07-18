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

output "cluster_security_group_id" {
  description = "The ID of the security group created by this module for securing the Elasticsearch cluster."
  value       = module.elasticsearch.cluster_security_group_id
}

output "aws_instance_public_ip" {
  description = "The public IP of the bastion host which you can SSH into to run curl commands against the Elasticsearch cluster."
  value       = aws_instance.server.public_ip
}

output "aws_instance_key_name" {
  description = "The key pair name used to authenticate SSH on the bastion host."
  value       = aws_instance.server.key_name
}
