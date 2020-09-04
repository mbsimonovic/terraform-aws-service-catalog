output "iam_role_arn" {
  description = "The ARN of the IAM role"
  value       = module.gruntwork_access.iam_role_arn
}

output "iam_role_name" {
  description = "The name of the IAM role"
  value       = module.gruntwork_access.iam_role_name
}