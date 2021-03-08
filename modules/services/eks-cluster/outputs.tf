output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster that was deployed."
  value       = module.eks_cluster.eks_cluster_arn
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster that was deployed."
  value       = module.eks_cluster.eks_cluster_name
}

output "eks_worker_asg_names" {
  description = "The list of names of the ASGs that were deployed to act as EKS workers."
  value       = module.eks_workers.eks_worker_asg_names
}

output "eks_worker_security_group_id" {
  description = "The ID of the AWS Security Group associated with the EKS workers."
  value       = module.eks_workers.eks_worker_security_group_id
}

output "eks_worker_iam_role_arn" {
  description = "The ARN of the IAM role associated with the EKS workers."
  value       = module.eks_workers.eks_worker_iam_role_arn
}

output "eks_worker_iam_role_name" {
  description = "The name of the IAM role associated with the EKS workers."
  value       = module.eks_workers.eks_worker_iam_role_name
}

output "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This outputs a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL."
  value = {
    openid_connect_provider_arn = module.eks_cluster.eks_iam_openid_connect_provider_arn
    openid_connect_provider_url = module.eks_cluster.eks_iam_openid_connect_provider_url
  }
}

output "eks_default_fargate_execution_role_arn" {
  description = "A basic IAM Role ARN that has the minimal permissions to pull images from ECR that can be used for most Pods as Fargate Execution Role that do not need to interact with AWS."
  value       = module.eks_cluster.eks_default_fargate_execution_role_arn
}

output "aws_auth_merger_namespace" {
  description = "The namespace name for the aws-auth-merger add on, if created."
  value       = local.aws_auth_merger_namespace_name
}

# CloudWatch Dashboard Widgets

output "metric_widget_worker_cpu_usage" {
  description = "A CloudWatch Dashboard widget that graphs CPU usage (percentage) of the EKS workers."
  value       = module.metric_widget_worker_cpu_usage.widget
}

output "metric_widget_worker_memory_usage" {
  description = "A CloudWatch Dashboard widget that graphs memory usage (percentage) of the EKS workers."
  value       = module.metric_widget_worker_memory_usage.widget
}

output "metric_widget_worker_disk_usage" {
  description = "A CloudWatch Dashboard widget that graphs disk usage (percentage) of the EKS workers."
  value       = module.metric_widget_worker_disk_usage.widget
}
