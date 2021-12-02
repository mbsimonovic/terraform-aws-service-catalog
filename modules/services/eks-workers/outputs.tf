output "worker_asg_names" {
  description = "The list of names of the ASGs that were deployed to act as EKS workers."
  value       = local.worker_asg_names
}

output "self_managed_worker_security_group_id" {
  description = "The ID of the AWS Security Group associated with the self-managed EKS workers."
  value       = module.self_managed_workers.eks_worker_security_group_id
}

output "self_managed_worker_iam_role_arn" {
  description = "The ARN of the IAM role associated with the self-managed EKS workers."
  value       = module.self_managed_workers.eks_worker_iam_role_arn
}

output "self_managed_worker_iam_role_name" {
  description = "The name of the IAM role associated with the self-managed EKS workers."
  value       = module.self_managed_workers.eks_worker_iam_role_name
}

output "metric_widget_self_managed_worker_cpu_usage" {
  description = "A CloudWatch Dashboard widget that graphs CPU usage (percentage) of the self-managed EKS workers."
  value       = module.metric_widget_self_managed_worker_cpu_usage.widget
}

output "metric_widget_self_managed_worker_memory_usage" {
  description = "A CloudWatch Dashboard widget that graphs memory usage (percentage) of the self-managed EKS workers."
  value       = module.metric_widget_self_managed_worker_memory_usage.widget
}

output "metric_widget_self_managed_worker_disk_usage" {
  description = "A CloudWatch Dashboard widget that graphs disk usage (percentage) of the self-managed EKS workers."
  value       = module.metric_widget_self_managed_worker_disk_usage.widget
}

output "managed_node_group_worker_iam_role_arn" {
  description = "The ARN of the IAM role associated with the Managed Node Group EKS workers."
  value       = module.managed_node_groups.eks_worker_iam_role_arn
}

output "managed_node_group_worker_iam_role_name" {
  description = "The name of the IAM role associated with the Managed Node Group EKS workers."
  value       = module.managed_node_groups.eks_worker_iam_role_name
}

output "managed_node_group_worker_shared_security_group_id" {
  description = "The ID of the common AWS Security Group associated with all the managed EKS workers."
  value       = length(aws_security_group.managed_node_group) > 0 ? aws_security_group.managed_node_group[0].id : null
}

output "managed_node_group_worker_security_group_ids" {
  description = "Map of Node Group names to Auto Scaling Group security group IDs. Empty if var.cluster_instance_keypair_name is not set."
  value       = module.managed_node_groups.eks_worker_asg_security_group_ids
}

output "managed_node_group_arns" {
  description = "Map of Node Group names to ARNs of the created EKS Node Groups."
  value       = module.managed_node_groups.eks_worker_node_group_arns
}

output "metric_widget_managed_node_group_worker_cpu_usage" {
  description = "A CloudWatch Dashboard widget that graphs CPU usage (percentage) of the Managed Node Group EKS workers."
  value       = module.metric_widget_managed_node_group_worker_cpu_usage.widget
}

output "metric_widget_managed_node_group_worker_memory_usage" {
  description = "A CloudWatch Dashboard widget that graphs memory usage (percentage) of the Managed Node Group EKS workers."
  value       = module.metric_widget_managed_node_group_worker_memory_usage.widget
}

output "metric_widget_managed_node_group_worker_disk_usage" {
  description = "A CloudWatch Dashboard widget that graphs disk usage (percentage) of the Managed Node Group EKS workers."
  value       = module.metric_widget_managed_node_group_worker_disk_usage.widget
}
