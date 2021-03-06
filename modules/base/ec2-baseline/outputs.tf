output "ssh_grunt_permissions_json" {
  description = "The ssh-grunt IAM policy in JSON format."
  value       = module.ssh_grunt_policies.ssh_grunt_permissions
}

output "cloudwatch_log_aggregation_policy_name" {
  description = "The name of the CloudWatch Logs aggregation IAM policy."
  value       = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_name
}

output "cloudwatch_log_aggregation_policy_id" {
  description = "The ID of the CloudWatch Logs aggregation IAM policy."
  value       = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_id
}

output "cloudwatch_log_aggregation_policy_arn" {
  description = "The ARN of the CloudWatch Logs aggregation IAM policy."
  value       = module.cloudwatch_log_aggregation.cloudwatch_log_aggregation_policy_arn
}

output "cloudwatch_logs_permissions_json" {
  description = "The CloudWatch Logs aggregation IAM policy in JSON format."
  value       = module.cloudwatch_log_aggregation.cloudwatch_logs_permissions_json
}

output "cloudwatch_metrics_policy_name" {
  description = "The name of the CloudWatch Metrics IAM policy."
  value       = module.cloudwatch_metrics.cloudwatch_metrics_policy_name
}

output "cloudwatch_metrics_policy_id" {
  description = "The ID of the CloudWatch Metrics IAM policy."
  value       = module.cloudwatch_metrics.cloudwatch_metrics_policy_id
}

output "cloudwatch_metrics_policy_arn" {
  description = "The ID of the CloudWatch Metrics IAM policy."
  value       = module.cloudwatch_metrics.cloudwatch_metrics_policy_arn
}

output "cloudwatch_metrics_read_write_permissions_json" {
  description = "The CloudWatch Metrics IAM policy in JSON format."
  value       = module.cloudwatch_metrics.cloudwatch_metrics_read_write_permissions_json
}

output "cloud_init_rendered" {
  description = "The final rendered cloud-init config used to initialize the instance."
  value       = var.should_render_cloud_init ? data.cloudinit_config.cloud_init[0].rendered : null
}

output "existing_ami" {
  description = "The ID of an existing AMI that was retrieved using ami_filters, or provided as input."
  value       = local.use_ami_lookup ? data.aws_ami.existing[0].id : var.ami
}
