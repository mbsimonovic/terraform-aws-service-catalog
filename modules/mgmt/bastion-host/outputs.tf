output "dns_name" {
  description = "The fully qualified name of the bastion host."
  value       = aws_route53_record.bastion_host.fqdn
}

output "bastion_host_public_ip" {
  description = "The public IP address of the bastion host."
  value       = module.bastion.public_ip
}

output "bastion_host_private_ip" {
  description = "The private IP address of the bastion host."
  value       = module.bastion.private_ip
}

output "bastion_host_security_group_id" {
  description = "The ID of the bastion hosts's security group."
  value       = module.bastion.security_group_id
}

output "bastion_host_iam_role_arn" {
  description = "The ARN of the bastion host's IAM role."
  value       = module.bastion.iam_role_id
}

output "bastion_host_instance_id" {
  description = "The EC2 instance ID of the bastion host."
  value       = module.bastion.id
}
