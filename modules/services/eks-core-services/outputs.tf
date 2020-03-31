output "container_logs_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group used to store the container logs."
  value       = aws_cloudwatch_log_group.eks_cluster.name
}
