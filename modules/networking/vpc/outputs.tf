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

output "default_security_group_id" {
  description = "The ID of the default security group of this VPC."
  value       = module.vpc.default_security_group_id
}

output "public_subnets" {
  description = "A map of all public subnets, with the subnet name as key, and all `aws-subnet` properties as the value."
  value       = module.vpc.public_subnets
}

output "private_app_subnets" {
  description = "A map of all private-app subnets, with the subnet name as key, and all `aws-subnet` properties as the value."
  value       = module.vpc.private_app_subnets
}

output "private_persistence_subnets" {
  description = "A map of all private-persistence subnets, with the subnet name as key, and all `aws-subnet` properties as the value."
  value       = module.vpc.private_persistence_subnets
}

output "public_subnet_cidr_blocks" {
  description = "The public IP address range of the VPC in CIDR notation."
  value       = module.vpc.public_subnet_cidr_blocks
}

output "private_app_subnet_cidr_blocks" {
  description = "The private IP address range of the VPC in CIDR notation."
  value       = module.vpc.private_app_subnet_cidr_blocks
}

output "private_persistence_subnet_cidr_blocks" {
  description = "The private IP address range of the VPC Persistence tier in CIDR notation."
  value       = module.vpc.private_persistence_subnet_cidr_blocks
}

output "public_subnet_ids" {
  description = "A list of IDs of the public subnets of the VPC."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "A list of IDs of the private app subnets in the VPC"
  value       = module.vpc.private_app_subnet_ids
}

output "private_persistence_subnet_ids" {
  description = "The IDs of the private persistence tier subnets of the VPC."
  value       = module.vpc.private_persistence_subnet_ids
}

output "public_subnet_route_table_id" {
  description = "The ID of the public routing table."
  value       = module.vpc.public_subnet_route_table_id
}

output "private_app_subnet_route_table_ids" {
  description = "A list of IDs of the private app subnet routing table."
  value       = module.vpc.private_app_subnet_route_table_ids
}

output "private_persistence_route_table_ids" {
  description = "A list of IDs of the private persistence subnet routing table."
  value       = module.vpc.private_persistence_route_table_ids
}

output "nat_gateway_public_ips" {
  description = "A list of public IPs from the NAT Gateway"
  value       = module.vpc.nat_gateway_public_ips
}

output "nat_gateway_public_ip_count" {
  description = "Count of public IPs from the NAT Gateway"
  value       = length(module.vpc.nat_gateway_public_ips)
}

output "public_subnets_network_acl_id" {
  description = "The ID of the public subnet's ACL"
  value       = module.vpc_network_acls.public_subnets_network_acl_id
}

output "private_app_subnets_network_acl_id" {
  description = "The ID of the private subnet's ACL"
  value       = module.vpc_network_acls.private_app_subnets_network_acl_id
}

output "private_persistence_subnets_network_acl_id" {
  description = "The ID of the private persistence subnet's ACL"
  value       = module.vpc_network_acls.private_persistence_subnets_network_acl_id
}

output "num_availability_zones" {
  description = "The number of availability zones of the VPC"
  value       = module.vpc.num_availability_zones
}

output "availability_zones" {
  description = "The availability zones of the VPC"
  value       = module.vpc.availability_zones
}

output "vpc_ready" {
  description = "Indicates whether or not the VPC has finished creating"
  value       = module.vpc.vpc_ready
}


output "s3_vpc_endpoint_id" {
  value = module.vpc.s3_vpc_endpoint_id
}

output "dynamodb_vpc_endpoint_id" {
  value = module.vpc.dynamodb_vpc_endpoint_id
}