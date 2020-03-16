output "ecr_repo_arns" {
  description = "A map of repository name to its ECR ARN."
  value       = { for repo_name, repo in aws_ecr_repository.repos : repo_name => repo.arn }
}

output "ecr_repo_urls" {
  description = "A map of repository name to its URL."
  value       = { for repo_name, repo in aws_ecr_repository.repos : repo_name => repo.repository_url }
}

output "ecr_read_policy_actions" {
  description = "A list of IAM policy actions necessary for ECR read access."
  value       = local.iam_read_access_policies
}

output "ecr_write_policy_actions" {
  description = "A list of IAM policy actions necessary for ECR write access."
  value       = local.iam_write_access_policies
}
