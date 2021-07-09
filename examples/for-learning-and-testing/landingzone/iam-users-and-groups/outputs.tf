# ---------------------------------------------------------------------------------------------------------------------
# IAM USERS OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "user_arns" {
  description = "A map of usernames to the ARN for that IAM user."
  value       = module.iam_users_and_groups.user_arns
}

output "user_passwords" {
  description = "A map of usernames to that user's AWS Web Console password, encrypted with that user's PGP key (only shows up for users with create_login_profile = true). You can decrypt the password on the CLI: echo <password> | base64 --decode | keybase pgp decrypt"
  value       = module.iam_users_and_groups.user_passwords
}

output "user_access_keys" {
  description = "A map of usernames to that user's access keys (a map with keys access_key_id and secret_access_key), with the secret_access_key encrypted with that user's PGP key (only shows up for users with create_access_keys = true). You can decrypt the secret_access_key on the CLI: echo <secret_access_key> | base64 --decode | keybase pgp decrypt"
  value       = module.iam_users_and_groups.user_access_keys
}
