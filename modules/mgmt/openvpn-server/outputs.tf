output "autoscaling_group_id" {
  description = "The OpenVPN server's AutoScaling Group ID."
  value       = module.openvpn.autoscaling_group_id
}

output "dns_name" {
  description = "The fully qualified name of the OpenVPN server."
  value       = element(concat(aws_route53_record.openvpn.*.fqdn, [""]), 0)
}

output "openvpn_server_public_ip" {
  description = "The public IP address of the OpenVPN server."
  value       = module.openvpn.public_ip
}

output "openvpn_server_private_ip" {
  description = "The private IP address of the OpenVPN server."
  value       = module.openvpn.private_ip
}

output "openvpn_server_elastic_ip" {
  description = "The Elastic IP address of the OpenVPN server."
  value       = module.openvpn.elastic_ip
}

output "openvpn_server_security_group_id" {
  description = "The ID of the OpenVPN server security group."
  value       = module.openvpn.security_group_id
}

output "openvpn_server_iam_role_id" {
  description = "The name of the IAM role of the OpenVPN server."
  value       = module.openvpn.iam_role_id
}

output "client_request_queue" {
  description = "The ARN of the SQS queue used by openvpn-admin clients to request certificates."
  value       = module.openvpn.client_request_queue
}

output "client_revocation_queue" {
  description = "The ARN of the SQS queue used by openvpn-admin clients to revoke certificates."
  value       = module.openvpn.client_revocation_queue
}

output "backup_bucket_name" {
  description = "The name of the S3 bucket that will be used to backup PKI secrets."
  value       = module.openvpn.backup_bucket_name
}

output "allow_certificate_requests_for_external_accounts_iam_role_id" {
  description = "The name of the IAM role that can be assumed by external accounts when requesting certificates."
  value       = module.openvpn.allow_certificate_requests_for_external_accounts_iam_role_id
}

output "allow_certificate_requests_for_external_accounts_iam_role_arn" {
  description = "The ARN of the IAM role that can be assumed by external accounts when requesting certificates."
  value       = module.openvpn.allow_certificate_requests_for_external_accounts_iam_role_arn
}

output "allow_certificate_revocations_for_external_accounts_iam_role_id" {
  description = "The name of the IAM role that can be assumed by external accounts when revoking certificates."
  value       = module.openvpn.allow_certificate_revocations_for_external_accounts_iam_role_id
}

output "allow_certificate_revocations_for_external_accounts_iam_role_arn" {
  description = "The ARN of the IAM role that can be assumed by external accounts when revoking certificates."
  value       = module.openvpn.allow_certificate_revocations_for_external_accounts_iam_role_arn
}
