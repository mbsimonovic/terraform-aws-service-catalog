output "ecr_repo_arns" {
  description = "A map of repository name to its ECR ARN."
  value       = { for repo_name, repo in aws_ecr_repository.repos : repo_name => repo.arn }
}

output "ecr_repo_urls" {
  description = "A map of repository name to its URL."
  value       = { for repo_name, repo in aws_ecr_repository.repos : repo_name => repo.repository_url }
}
