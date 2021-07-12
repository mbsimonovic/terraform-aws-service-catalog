# ---------------------------------------------------------------------------------------------------------------------
# IAM GROUPS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "billing_iam_group_name" {
  value = module.iam_groups.billing_iam_group_name
}

output "billing_iam_group_arn" {
  value = module.iam_groups.billing_iam_group_arn
}

output "support_iam_group_name" {
  value = module.iam_groups.support_iam_group_name
}

output "support_iam_group_arn" {
  value = module.iam_groups.support_iam_group_arn
}

output "logs_iam_group_name" {
  value = module.iam_groups.logs_iam_group_name
}

output "logs_iam_group_arn" {
  value = module.iam_groups.logs_iam_group_arn
}

output "developers_iam_group_name" {
  value = module.iam_groups.developers_iam_group_name
}

output "developers_iam_group_arn" {
  value = module.iam_groups.developers_iam_group_arn
}

output "full_access_iam_group_name" {
  value = module.iam_groups.full_access_iam_group_name
}

output "full_access_iam_group_arn" {
  value = module.iam_groups.full_access_iam_group_arn
}

output "ssh_grunt_users_group_names" {
  value = module.iam_groups.ssh_grunt_users_group_names
}

output "ssh_grunt_users_group_arns" {
  value = module.iam_groups.ssh_grunt_users_group_arns
}

output "ssh_grunt_sudo_users_group_names" {
  value = module.iam_groups.ssh_grunt_sudo_users_group_names
}

output "ssh_grunt_sudo_users_group_arns" {
  value = module.iam_groups.ssh_grunt_sudo_users_group_arns
}

output "read_only_iam_group_name" {
  value = module.iam_groups.read_only_iam_group_name
}

output "read_only_iam_group_arn" {
  value = module.iam_groups.read_only_iam_group_arn
}

output "houston_cli_users_iam_group_name" {
  value = module.iam_groups.houston_cli_users_iam_group_name
}

output "houston_cli_users_iam_group_arn" {
  value = module.iam_groups.houston_cli_users_iam_group_arn
}

output "use_existing_iam_roles_iam_group_name" {
  value = module.iam_groups.use_existing_iam_roles_iam_group_name
}

output "use_existing_iam_roles_iam_group_arn" {
  value = module.iam_groups.use_existing_iam_roles_iam_group_arn
}

output "iam_self_mgmt_iam_group_name" {
  value = module.iam_groups.iam_self_mgmt_iam_group_name
}

output "iam_self_mgmt_iam_group_arn" {
  value = module.iam_groups.iam_self_mgmt_iam_group_arn
}

output "iam_self_mgmt_iam_policy_arn" {
  value = module.iam_groups.iam_self_mgmt_iam_policy_arn
}

output "iam_admin_iam_group_name" {
  value = module.iam_groups.iam_admin_iam_group_name
}

output "iam_admin_iam_group_arn" {
  value = module.iam_groups.iam_admin_iam_group_arn
}

output "iam_admin_iam_policy_arn" {
  value = module.iam_groups.iam_admin_iam_policy_arn
}

output "require_mfa_policy" {
  value = module.iam_groups.require_mfa_policy
}

output "cross_account_access_group_arns" {
  value = module.iam_groups.cross_account_access_group_arns
}

output "cross_account_access_group_names" {
  value = module.iam_groups.cross_account_access_group_names
}

output "cross_account_access_all_group_arn" {
  value = module.iam_groups.cross_account_access_all_group_arn
}

output "cross_account_access_all_group_name" {
  value = module.iam_groups.cross_account_access_all_group_name
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM USERS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "user_arns" {
  description = "A map of usernames to the ARN for that IAM user."
  value       = module.iam_users.user_arns
}

output "user_passwords" {
  description = "A map of usernames to that user's AWS Web Console password, encrypted with that user's PGP key (only shows up for users with create_login_profile = true). You can decrypt the password on the CLI: echo <password> | base64 --decode | keybase pgp decrypt"
  value       = module.iam_users.user_passwords
}

output "user_access_keys" {
  description = "A map of usernames to that user's access keys (a map with keys access_key_id and secret_access_key), with the secret_access_key encrypted with that user's PGP key (only shows up for users with create_access_keys = true). You can decrypt the secret_access_key on the CLI: echo <secret_access_key> | base64 --decode | keybase pgp decrypt"
  value       = module.iam_users.user_access_keys
}
