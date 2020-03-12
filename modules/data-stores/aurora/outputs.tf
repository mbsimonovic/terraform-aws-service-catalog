output "cluster_id" {
  description = "The ID of the RDS Aurora cluster (e.g TODO)."
  value       = module.database.cluster_id
}

output "cluster_arn" {
  description = "The ARN of the RDS Aurora cluster."
  value       = module.database.cluster_arn
}

output "primary_endpoint" {
  description = "The primary endpoint of the RDS Aurora cluster that you can use to make requests to."
  value       = module.database.cluster_endpoint
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
