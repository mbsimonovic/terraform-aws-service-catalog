output "dns_name" {
  description = "The fully qualified name of the bastion host."
  value       = module.bastion.dns_name
}

output "bastion_host_public_ip" {
  description = "The public IP address of the bastion host."
  value       = module.bastion.bastion_host_public_ip
}

output "bastion_host_private_ip" {
  description = "The private IP address of the bastion host."
  value       = module.bastion.bastion_host_private_ip
}

output "bastion_host_security_group_id" {
  description = "The ID of the bastion hosts's security group."
  value       = module.bastion.bastion_host_security_group_id
}

output "bastion_host_iam_role_arn" {
  description = "The ARN of the bastion host's IAM role."
  value       = module.bastion.bastion_host_iam_role_arn
}

output "bastion_host_instance_id" {
  description = "The EC2 instance ID of the bastion host."
  value       = module.bastion.bastion_host_instance_id
}
