# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED SENSITIVE PARAMETERS
# These variables are expected to be passed in via environment variables by the operator when calling this terraform
# module.
# Set using the env var TF_VAR_varname.
# ---------------------------------------------------------------------------------------------------------------------

# TF_VAR_master_password
variable "master_password" {
  description = "The password for the master user."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name used to namespace all the resources created by the RDS module. Must be unique in this region. Must be a lowercase string."
  type        = string
  default     = "rds"
}

variable "master_username" {
  description = "The username for the master user."
  type        = string
  default     = "rds"
}

variable "db_name" {
  description = "The name for your database of up to 8 alpha-numeric characters. If you do not provide a name, Amazon RDS will not create a database in the DB cluster you are creating."
  type        = string
  default     = "rds"
}

variable "share_snapshot_with_account_id" {
  description = "The ID of the AWS Account that the snapshot should be shared with."
  type        = string
  default     = null
}

variable "engine" {
  description = "The name of the database engine to be used for the RDS instance. For the complete list of possible values, see the engine request parameter here: https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html."
  type        = string
  default     = "mysql"
}

variable "engine_version" {
  description = "The version of var.engine to use (e.g. 8.0.17 for mysql)."
  type        = string
  default     = "8.0.17"
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}
