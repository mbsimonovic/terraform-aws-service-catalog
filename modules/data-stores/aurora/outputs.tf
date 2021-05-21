output "cluster_id" {
  description = "The ID of the RDS Aurora cluster (e.g TODO)."
  value       = module.database.cluster_id
}

output "cluster_resource_id" {
  description = "The unique resource ID assigned to the cluster e.g. cluster-POBCBQUFQC56EBAAWXGFJ77GRU. This is useful for allowing database authentication via IAM."
  value       = module.database.cluster_resource_id
}

output "cluster_arn" {
  description = "The ARN of the RDS Aurora cluster."
  value       = module.database.cluster_arn
}

output "primary_endpoint" {
  description = "The primary endpoint of the RDS Aurora cluster that you can use to make requests to."
  value       = module.database.cluster_endpoint
}

output "primary_host" {
  description = "The host portion of the Aurora endpoint. primary_endpoint is in the form '<host>:<port>', and this output returns just the host part."
  value       = local.primary_host
}

output "instance_endpoints" {
  description = "A list of endpoints of the RDS instances that you can use to make requests to."
  value       = module.database.instance_endpoints
}

output "port" {
  description = "The port used by the RDS Aurora cluster for handling database connections."
  value       = module.database.port
}

output "create_snapshot_lambda_arn" {
  description = "The ARN of the AWS Lambda Function used for periodically taking snapshots to share with secondary accounts."
  value       = module.create_snapshot.lambda_function_arn
}

output "share_snapshot_lambda_arn" {
  description = "The ARN of the AWS Lambda Function used for sharing manual snapshots with secondary accounts."
  value       = module.share_snapshot.lambda_function_arn
}

output "cleanup_snapshots_lambda_arn" {
  description = "The ARN of the AWS Lambda Function used for cleaning up manual snapshots taken for sharing with secondary accounts."
  value       = module.cleanup_snapshots.lambda_function_arn
}

# CloudWatch Dashboard Widgets

output "all_metric_widgets" {
  description = "A list of all the CloudWatch Dashboard metric widgets available in this module."
  value = [
    module.metric_widget_aurora_cpu_usage.widget,
    module.metric_widget_aurora_memory.widget,
    module.metric_widget_aurora_disk_space.widget,
    module.metric_widget_aurora_db_connections.widget,
    module.metric_widget_aurora_read_latency.widget,
    module.metric_widget_aurora_write_latency.widget,
  ]
}

output "metric_widget_aurora_cpu_usage" {
  description = "A CloudWatch Dashboard widget that graphs CPU usage (percentage) of the Aurora cluster."
  value       = module.metric_widget_aurora_cpu_usage.widget
}

output "metric_widget_aurora_memory" {
  description = "A CloudWatch Dashboard widget that graphs available memory (in bytes) on the Aurora cluster."
  value       = module.metric_widget_aurora_memory.widget
}

output "metric_widget_aurora_disk_space" {
  description = "A CloudWatch Dashboard widget that graphs available disk space (in bytes) on the Aurora cluster."
  value       = module.metric_widget_aurora_disk_space.widget
}

output "metric_widget_aurora_db_connections" {
  description = "A CloudWatch Dashboard widget that graphs the number of active database connections of the Aurora cluster."
  value       = module.metric_widget_aurora_db_connections.widget
}

output "metric_widget_aurora_read_latency" {
  description = "A CloudWatch Dashboard widget that graphs the average amount of time taken per disk I/O operation on reads."
  value       = module.metric_widget_aurora_read_latency.widget
}

output "metric_widget_aurora_write_latency" {
  description = "A CloudWatch Dashboard widget that graphs the average amount of time taken per disk I/O operation on writes."
  value       = module.metric_widget_aurora_write_latency.widget
}
