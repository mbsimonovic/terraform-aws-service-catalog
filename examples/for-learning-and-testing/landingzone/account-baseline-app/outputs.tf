# ---------------------------------------------------------------------------------------------------------------------
# CONFIG OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "config_s3_bucket_names" {
  description = "The names of the S3 bucket used by AWS Config to store configuration items."
  value       = module.security_baseline.config_s3_bucket_names
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDTRAIL OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "cloudtrail_trail_arn" {
  description = "The ARN of the cloudtrail trail."
  value       = module.security_baseline.cloudtrail_trail_arn
}

output "cloudtrail_s3_bucket_name" {
  description = "The name of the S3 bucket where cloudtrail logs are delivered."
  value       = module.security_baseline.cloudtrail_s3_bucket_name
}

output "cloudtrail_kms_key_arn" {
  description = "The ARN of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.security_baseline.cloudtrail_kms_key_arn
}

output "cloudtrail_kms_key_alias_name" {
  description = "The alias of the KMS key used by the S3 bucket to encrypt cloudtrail logs."
  value       = module.security_baseline.cloudtrail_kms_key_alias_name
}

output "cloudtrail_cloudwatch_group_name" {
  description = "The name of the cloudwatch log group."
  value       = module.security_baseline.cloudtrail_cloudwatch_group_name
}

# ---------------------------------------------------------------------------------------------------------------------
# KMS CMK OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "kms_key_arns" {
  description = "A map from region to ARNs of the KMS CMKs that were created. The value will also be a map mapping the keys from the var.kms_customer_master_keys input variable to the corresponding ARN."
  value       = module.security_baseline.kms_key_arns
}

output "kms_key_aliases" {
  description = "A map from region to aliases of the KMS CMKs that were created. The value will also be a map mapping the keys from the var.customer_master_keys input variable to the corresponding alias."
  value       = module.security_baseline.kms_key_aliases
}
