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
