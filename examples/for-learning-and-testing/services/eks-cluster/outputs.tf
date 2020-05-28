output "private_subnet_ids" {
  description = "The list of IDs of private subnets that can be used for Fargate."
  value       = module.vpc.private_app_subnet_ids
}

output "eks_cluster_vpc_id" {
  description = "The ID of the VPC where the EKS cluster is deployed."
  value       = module.vpc.vpc_id
}

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
  value       = module.eks_cluster.eks_worker_asg_names
}

output "eks_worker_security_group_id" {
  description = "The ID of the AWS Security Group associated with the EKS workers."
  value       = module.eks_cluster.eks_worker_security_group_id
}

output "eks_worker_iam_role_arn" {
  description = "The ARN of the IAM role associated with the EKS workers."
  value       = module.eks_cluster.eks_worker_iam_role_arn
}

output "eks_worker_iam_role_name" {
  description = "The name of the IAM role associated with the EKS workers."
  value       = module.eks_cluster.eks_worker_iam_role_name
}

output "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This outputs a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL."
  value       = module.eks_cluster.eks_iam_role_for_service_accounts_config
}

output "eks_default_fargate_execution_role_arn" {
  description = "A basic IAM Role ARN that has the minimal permissions to pull images from ECR that can be used for most Pods as Fargate Execution Role that do not need to interact with AWS."
  value       = module.eks_cluster.eks_default_fargate_execution_role_arn
}
