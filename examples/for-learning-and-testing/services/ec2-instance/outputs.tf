output "dns_name" {
  description = "The fully qualified name of the EC2 instance."
  value       = module.ec2_instance.dns_name
}

output "ec2_instance_public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = module.ec2_instance.ec2_instance_public_ip
}

output "ec2_instance_private_ip" {
  description = "The private IP address of the EC2 instance."
  value       = module.ec2_instance.ec2_instance_private_ip
}

output "ec2_instance_security_group_id" {
  description = "The ID of the EC2 instance's security group."
  value       = module.ec2_instance.ec2_instance_security_group_id
}

output "ec2_instance_iam_role_arn" {
  description = "The ARN of the EC2 instance's IAM role."
  value       = module.ec2_instance.ec2_instance_iam_role_arn
}

output "ec2_instance_instance_id" {
  description = "The EC2 instance ID of the EC2 instance."
  value       = module.ec2_instance.ec2_instance_instance_id
}

output "ec2_instance_volume_device_name_1" {
  description = "The device name for the first volume."
  value       = module.ec2_instance.ec2_instance_volume_parameters["demo-volume"].device_name
}

output "ec2_instance_volume_mount_point_1" {
  description = "The mount point for the first volume."
  value       = module.ec2_instance.ec2_instance_volume_parameters["demo-volume"].mount_point
}


output "ec2_instance_volume_id_1" {
  description = "The volume id of the first volume."
  value       = module.ec2_instance.ec2_instance_volume_info["demo-volume"].id
}
