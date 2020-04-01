output "namespace_name" {
  description = "the name of the created namespace."
  value       = module.namespace.name
}

output "namespace_rbac_access_all_role" {
  description = "the name of the rbac role that grants admin level permissions on the namespace."
  value       = module.namespace.rbac_access_all_role
}

output "namespace_rbac_access_read_only_role" {
  description = "the name of the rbac role that grants read only permissions on the namespace."
  value       = module.namespace.rbac_access_read_only_role
}
