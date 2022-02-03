output "public_subnet_ids" {
  description = "The IDs of the public subnets from the VPC"
  value       = module.vpc.public_subnet_ids
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = module.vpc.vpc_name
}

output "route_table_ids" {
  description = "The list of IDs of the Route Tables that are created for the VPC."
  value = compact(concat(
    [module.vpc.public_subnet_route_table_id],
    module.vpc.private_subnet_route_table_ids,
  ))
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = var.cidr_block
}

output "instance_ip" {
  description = "The IP of the instance that runs inside the VPC"
  value       = aws_instance.example.public_ip
}
