output "container_logs_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group used to store the container logs."
  value       = local.maybe_log_group
}
