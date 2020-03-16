output "ecr_repo_arns" {
  description = "A map of repository name to its ECR ARN."
  value       = module.ecr_repos.ecr_repo_arns
}

output "ecr_repo_urls" {
  description = "A map of repository name to its URL."
  value       = module.ecr_repos.ecr_repo_urls
}
