# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

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
variable "name" {
  description = "The name used to namespace all the Aurora resources created by these templates, including the cluster and cluster instances (e.g. drupaldb). Must be unique in this region. Must be a lowercase string."
  type        = string
  default     = "aurora"
}

variable "master_password" {
  description = "The password for the master user."
  type        = string
  default     = null
}

variable "master_username" {
  description = "The username for the master user."
  type        = string
  default     = "aurora"
}

variable "db_name" {
  description = "The name for your database of up to 8 alpha-numeric characters. If you do not provide a name, Amazon RDS will not create a database in the DB cluster you are creating."
  type        = string
  default     = "aurora"
}

variable "share_snapshot_with_account_id" {
  description = "The ID of the AWS Account that the snapshot should be shared with."
  type        = string
  default     = null
}

variable "engine" {
  description = "The name of the database engine to be used for the RDS instance. Must be one of: aurora, aurora-mysql, aurora-postgresql."
  type        = string
  default     = "aurora"
}

variable "engine_mode" {
  description = "The version of aurora to run - provisioned or serverless."
  type        = string
  default     = "provisioned"
}

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "db_cluster_custom_parameter_group" {
  description = "Configure a custom parameter group for the RDS DB cluster. This will create a new parameter group with the given parameters. When null, the database will be launched with the default parameter group."
  type = object({
    # Name of the parameter group to create
    name = string

    # The family of the DB cluster parameter group.
    family = string

    # The parameters to configure on the created parameter group.
    parameters = list(object({
      # Parameter name to configure.
      name = string

      # Vaue to set the parameter.
      value = string

      # When to apply the parameter. "immediate" or "pending-reboot".
      apply_method = string
    }))
  })
  default = null
}
