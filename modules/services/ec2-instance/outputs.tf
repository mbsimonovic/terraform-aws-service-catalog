output "dns_name" {
  description = "The fully qualified name of the EC2 server."
  value       = module.ec2_instance.fqdn
}

output "ec2_instance_public_ip" {
  description = "The public IP address of the EC2 server."
  value       = module.ec2_instance.public_ip
}

output "ec2_instance_private_ip" {
  description = "The private IP address of the EC2 server."
  value       = module.ec2_instance.private_ip
}

output "ec2_instance_security_group_id" {
  description = "The ID of the EC2 servers's security group."
  value       = module.ec2_instance.security_group_id
}

output "ec2_instance_iam_role_id" {
  description = "The ID of the EC2 server's IAM role."
  value       = module.ec2_instance.iam_role_id
}

output "ec2_instance_iam_role_name" {
  description = "The name of the EC2 server's IAM role."
  value       = module.ec2_instance.iam_role_name
}

output "ec2_instance_iam_role_arn" {
  description = "The ARN of the EC2 server's IAM role."
  value       = module.ec2_instance.iam_role_arn
}

output "ec2_instance_instance_id" {
  description = "The EC2 instance ID of the EC2 server."
  value       = module.ec2_instance.id
}

output "ec2_instance_volume_info" {
  description = "Info about the created EBS volumes."
  value       = aws_ebs_volume.ec2_instance
}

output "ec2_instance_volume_parameters" {
  description = "The input parameters for the EBS volumes."
  value       = var.ebs_volumes
}