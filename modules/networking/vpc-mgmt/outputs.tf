# ---------------------------------------------------------------------------------------------------------------------
# VPC OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the mgmt VPC."
  value       = module.vpc.vpc_id
}

output "vpc_name" {
  description = "The name of the mgmt VPC."
  value       = module.vpc.vpc_name
}

output "vpc_cidr_block" {
  description = "The CIDR block of the mgmt VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_cidr_blocks" {
  description = "The public subnet CIDR blocks of the mgmt VPC."
  value       = module.vpc.public_subnet_cidr_blocks
}

output "private_subnet_cidr_blocks" {
  description = "The private subnet CIDR blocks of the mgmt VPC."
  value       = module.vpc.private_subnet_cidr_blocks
}

output "public_subnet_ids" {
  description = "The public subnet IDs of the mgmt VPC."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The private subnet IDs of the mgmt VPC."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_arns" {
  description = "The public subnet ARNs of the mgmt VPC."
  value       = module.vpc.public_subnet_arns
}

output "private_subnet_arns" {
  description = "The private subnet ARNs of the mgmt VPC."
  value       = module.vpc.private_subnet_arns
}

output "public_subnet_route_table_id" {
  description = "The ID of the public subnet route table of the mgmt VPC."
  value       = module.vpc.public_subnet_route_table_id
}

output "private_subnet_route_table_ids" {
  description = "The ID of the private subnet route table of the mgmt VPC."
  value       = module.vpc.private_subnet_route_table_ids
}

output "nat_gateway_public_ips" {
  description = "The public IP address(es) of the NAT gateway(s) of the mgmt VPC."
  value       = module.vpc.nat_gateway_public_ips
}

output "num_availability_zones" {
  description = "The number of availability zones used by the mgmt VPC."
  value       = module.vpc.num_availability_zones
}

output "vpc_ready" {
  description = "Indicates whether or not the VPC has finished creating"
  value       = module.vpc.vpc_ready
}
