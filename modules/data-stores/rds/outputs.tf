output "primary_id" {
  description = "The ID of the RDS DB instance."
  value       = module.database.primary_id
}

output "primary_arn" {
  description = "The ARN of the RDS DB instance."
  value       = module.database.primary_arn
}

output "primary_endpoint" {
  description = "The endpoint of the RDS DB instance that you can make requests to."
  value       = module.database.primary_endpoint
}

output "num_read_replicas" {
  description = "The number of read replicas for the RDS DB instance."
  value       = var.num_read_replicas
}

# These will only show up if you set num_read_replicas > 0
output "read_replica_ids" {
  description = "A list of IDs of the RDS DB instance's read replicas."
  value       = module.database.read_replica_ids
}

# These will only show up if you set num_read_replicas > 0
output "read_replica_arns" {
  description = "A list of ARNs of the RDS DB instance's read replicas."
  value       = module.database.read_replica_arns
}

# These will only show up if you set num_read_replicas > 0
output "read_replica_endpoints" {
  description = "A list of endpoints of the RDS DB instance's read replicas."
  value       = module.database.read_replica_endpoints
}

# The primary_endpoint is of the format <host>:<port>. This output returns just the host part.
output "primary_host" {
  description = "The host portion of the RDS DB instance endpoint. primary_endpoint is in the form '<host>:<port>'."
  value       = element(split(":", module.database.primary_endpoint), 0)
}

output "port" {
  description = "The port of the RDS DB instance."
  value       = module.database.port
}

output "name" {
  description = "The name of the RDS DB instance."
  value       = var.name
}

output "db_name" {
  description = "The name of the empty database created on this RDS DB instance."
  value       = module.database.db_name
}

output "metric_widget_rds_cpu_usage" {
  description = "A CloudWatch Dashboard Widget for CPU usage on the RDS DB instance."
  value       = module.metric_widget_rds_cpu_usage.widget
}

output "metric_widget_rds_memory" {
  description = "A CloudWatch Dashboard Widget for memory usage on the RDS DB instance."
  value       = module.metric_widget_rds_memory.widget
}

output "metric_widget_rds_disk_space" {
  description = "A CloudWatch Dashboard Widget for disk space on the RDS DB instance."
  value       = module.metric_widget_rds_disk_space.widget
}

output "metric_widget_rds_db_connections" {
  description = "A CloudWatch Dashboard Widget for database connections on the RDS DB instance."
  value       = module.metric_widget_rds_db_connections.widget
}

output "metric_widget_rds_read_latency" {
  description = "A CloudWatch Dashboard Widget for read latency on the RDS DB instance."
  value       = module.metric_widget_rds_read_latency.widget
}

output "metric_widget_rds_write_latency" {
  description = "A CloudWatch Dashboard Widget for write latency on the RDS DB instance."
  value       = module.metric_widget_rds_write_latency.widget
}