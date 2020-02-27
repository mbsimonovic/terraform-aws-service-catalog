output "public_subnet_ids" {
  description = "The IDs of the public subnets from the VPC"
  value       = module.vpc_app.public_subnet_ids
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc_app.vpc_id
}

output "instance_ip" {
  description = "The IP of the instance that runs inside the VPC"
  value       = aws_instance.example.public_ip
}
