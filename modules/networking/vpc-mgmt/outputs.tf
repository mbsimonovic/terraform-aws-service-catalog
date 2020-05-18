output "vpc_name" {
  description = "The name configured for VPC."
  value       = module.vpc.vpc_name
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The IP address range of the VPC in CIDR notation."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_cidr_blocks" {
  description = "The public IP address range of the VPC in CIDR notation."
  value       = module.vpc.public_subnet_cidr_blocks
}

output "private_subnet_cidr_blocks" {
  description = "The private IP address range of the VPC in CIDR notation."
  value       = module.vpc.private_subnet_cidr_blocks
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets in this VPC."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets in this VPC."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_route_table_id" {
  description = "The route table ID for the public subnets in this VPC."
  value       = module.vpc.public_subnet_route_table_id
}

output "private_subnet_route_table_ids" {
  description = "The route table ID for the private subnets in this VPC."
  value       = module.vpc.private_subnet_route_table_ids
}

output "nat_gateway_public_ips" {
  description = "The public IPs of the NAT gateways."
  value       = module.vpc.nat_gateway_public_ips
}

output "num_availability_zones" {
  description = "The number of availability zones used by this VPC."
  value       = module.vpc.num_availability_zones
}

output "availability_zones" {
  description = "A list of the availability zones used by this VPC."
  value       = module.vpc.availability_zones
}
