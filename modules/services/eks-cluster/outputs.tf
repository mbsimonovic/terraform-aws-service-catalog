output "eks_cluster_arn" {
  value = module.eks_cluster.eks_cluster_arn
}

output "eks_cluster_name" {
  value = module.eks_cluster.eks_cluster_name
}

output "eks_cluster_asg_name" {
  value = module.eks_workers.eks_worker_asg_name
}

output "eks_worker_security_group_id" {
  value = module.eks_workers.eks_worker_security_group_id
}

output "eks_worker_iam_role_arn" {
  value = module.eks_workers.eks_worker_iam_role_arn
}

output "eks_worker_iam_role_name" {
  value = module.eks_workers.eks_worker_iam_role_name
}

output "asg_name" {
  value = module.eks_workers.eks_worker_asg_name
}
