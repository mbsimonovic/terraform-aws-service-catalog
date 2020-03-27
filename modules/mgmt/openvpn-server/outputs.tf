output "autoscaling_group_id" {
  description = "The AutoScaling Group ID of the OpenVPN server."
  value       = module.openvpn.autoscaling_group_id
}

output "public_ip" {
  description = "The public IP address of the OpenVPN server."
  value       = module.openvpn.public_ip
}

output "private_ip" {
  description = "The private IP address of the OpenVPN server."
  value       = module.openvpn.private_ip
}

output "elastic_ip" {
  description = "The elastic IP address of the OpenVPN server."
  value       = module.openvpn.elastic_ip
}

output "security_group_id" {
  description = "The security group ID of the OpenVPN server."
  value       = module.openvpn.security_group_id
}

output "iam_role_id" {
  description = "The ID of the IAM role used by the OpenVPN server."
  value       = module.openvpn.iam_role_id
}

output "client_request_queue" {
  description = "The SQS queue used by the openvpn-admin tool for certificate requests."
  value       = module.openvpn.client_request_queue
}

output "client_revocation_queue" {
  description = "The SQS queue used by the openvpn-admin tool for certificate revocations."
  value       = module.openvpn.client_revocation_queue
}

output "backup_bucket_name" {
  description = "The S3 bucket used for backing up the OpenVPN PKI."
  value       = module.openvpn.backup_bucket_name
}

output "allow_certificate_requests_for_external_accounts_iam_role_id" {
  description = "The name of the IAM role that can be assumed from external accounts to request certificates."
  value       = module.openvpn.allow_certificate_requests_for_external_accounts_iam_role_id
}

output "allow_certificate_requests_for_external_accounts_iam_role_arn" {
  description = "The ARN of the IAM role that can be assumed from external accounts to request certificates."
  value       = module.openvpn.allow_certificate_requests_for_external_accounts_iam_role_arn
}

output "allow_certificate_revocations_for_external_accounts_iam_role_id" {
  description = "The name of the IAM role that can be assumed from external accounts to revoke certificates."
  value       = module.openvpn.allow_certificate_revocations_for_external_accounts_iam_role_id
}

output "allow_certificate_revocations_for_external_accounts_iam_role_arn" {
  description = "The ARN of the IAM role that can be assumed from external accounts to revoke certificates."
  value       = module.openvpn.allow_certificate_revocations_for_external_accounts_iam_role_arn
}

output "openvpn_users_group_name" {
  description = "The name of the OpenVPN users IAM group (to request certificates)."
  value       = module.openvpn.openvpn_users_group_name
}

output "openvpn_admins_group_name" {
  description = "The name of the OpenVPN admins IAM group (to request and revoke certificates)."
  value       = module.openvpn.openvpn_admins_group_name
}
