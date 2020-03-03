output "organization_arn" {
  description = "ARN of the organization."
  value       = module.root_baseline.organization_arn
}

output "organization_id" {
  description = "Identifier of the organization."
  value       = module.root_baseline.organization_id
}

output "master_account_arn" {
  description = "ARN of the master account."
  value       = module.root_baseline.master_account_arn
}

output "master_account_id" {
  description = "Identifier of the master account."
  value       = module.root_baseline.master_account_id
}

output "master_account_email" {
  description = "Email address of the master account."
  value       = module.root_baseline.master_account_email
}

# See https://www.terraform.io/docs/providers/aws/r/organizations_organization.html#accounts for available attributes
output "accounts" {
  description = "List of organization accounts including the master account."
  value       = module.root_baseline.accounts
}

# See https://www.terraform.io/docs/providers/aws/r/organizations_organization.html#non_master_accounts for available attributes
output "non_master_accounts" {
  description = "List of organization accounts excluding the master account."
  value       = module.root_baseline.non_master_accounts
}

# See https://www.terraform.io/docs/providers/aws/r/organizations_organization.html#roots for available attributes
output "root_accounts" {
  description = "List of organization roots."
  value       = module.root_baseline.root_accounts
}

// Majority of the module outputs omitted in the example
