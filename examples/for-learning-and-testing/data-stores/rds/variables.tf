# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED SENSITIVE PARAMETERS
# These variables are expected to be passed in via environment variables by the operator when calling this terraform
# module.
# Set using the env var TF_VAR_varname.
# ---------------------------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name used to namespace all the resources created by the RDS module. Must be unique in this region. Must be a lowercase string."
  type        = string
  default     = "rds"
}

variable "db_config_secrets_manager_id" {
  description = "The friendly name or ARN of an AWS Secrets Manager secret that contains database configuration information in the format outlined by this document: https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html. If you do not wish to use Secrets Manager, leave this as null, and use the master_username, master_password, db_name, engine, and port variables. Note that even with this precaution, this information will be stored in plaintext in the Terraform state file! See the following blog post for more details: https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1."
  type        = string
  default     = null
  # Use this variable to specify the ID of a Secrets Manager Secret. The value of the secret must be JSON of the format:
  # {
  #   "engine": "mysql",
  #   "username": "example-user",
  #   "password": "example-password",
  #   "dbname": "myDatabase",
  #   "port": "3306"
  # }
}

variable "master_username" {
  description = "The value to use for the master username of the database. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id."
  type        = string
  default     = null
}

variable "master_password" {
  description = "The value to use for the master password of the database. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id."
  type        = string
  default     = null
}

variable "db_name" {
  description = "The name for your database of up to 8 alpha-numeric characters. If you do not provide a name, Amazon RDS will not create a database in the DB cluster you are creating."
  type        = string
  default     = null
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "port" {
  description = "The port the DB will listen on (e.g. 3306). If not provided, will use the default for the selected engine. This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id."
  type        = number
  default     = null
}

variable "engine" {
  description = "The DB engine to use (e.g. mysql). This can also be provided via AWS Secrets Manager. See the description of db_config_secrets_manager_id."
  type        = string
  default     = null
}
