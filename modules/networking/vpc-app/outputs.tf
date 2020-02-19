output "vpc_name" {
  value = module.vpc.vpc_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "public_subnet_cidr_blocks" {
  value = module.vpc.public_subnet_cidr_blocks
}

output "private_app_subnet_cidr_blocks" {
  value = module.vpc.private_app_subnet_cidr_blocks
}

output "private_persistence_subnet_cidr_blocks" {
  value = module.vpc.private_persistence_subnet_cidr_blocks
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.vpc.private_app_subnet_ids
}

output "private_persistence_subnet_ids" {
  value = module.vpc.private_persistence_subnet_ids
}

output "public_subnet_route_table_id" {
  value = module.vpc.public_subnet_route_table_id
}

output "private_app_subnet_route_table_ids" {
  value = module.vpc.private_app_subnet_route_table_ids
}

output "private_persistence_route_table_ids" {
  value = module.vpc.private_persistence_route_table_ids
}

output "nat_gateway_public_ips" {
  value = module.vpc.nat_gateway_public_ips
}

output "nat_gateway_public_ip_count" {
  value = length(module.vpc.nat_gateway_public_ips)
}

output "public_subnets_network_acl_id" {
  value = module.vpc_network_acls.public_subnets_network_acl_id
}

output "private_app_subnets_network_acl_id" {
  value = module.vpc_network_acls.private_app_subnets_network_acl_id
}

output "private_persistence_subnets_network_acl_id" {
  value = module.vpc_network_acls.private_persistence_subnets_network_acl_id
}

output "num_availability_zones" {
  value = module.vpc.num_availability_zones
}

output "availability_zones" {
  value = module.vpc.availability_zones
}
output "origin_vpc_route53_resolver_endpoint_id" {
  value = module.dns_mgmt_to_app.origin_vpc_route53_resolver_endpoint_id
}

output "destination_vpc_route53_resolver_primary_ip" {
  value = module.dns_mgmt_to_app.destination_vpc_route53_resolver_primary_ip
}

output "destination_vpc_route53_resolver_secondary_ip" {
  value = module.dns_mgmt_to_app.destination_vpc_route53_resolver_secondary_ip
}
