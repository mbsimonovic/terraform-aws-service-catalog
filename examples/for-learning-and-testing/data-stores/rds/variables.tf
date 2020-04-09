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

variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

# Kubernetes parameters

variable "create_kubernetes_service" {
  description = "If true, this will create a Kubernetes Service in the configured Kubernetes cluster that can be used for service discovery against the data store. Customize the kubernetes provider to configure which Kubernetes cluster the Service should be created in."
  type        = bool
  default     = false
}

variable "kubernetes_namespace" {
  description = "The Namespace where the Kubernetes Service will be created. Only used if var.create_kubernetes_service is true."
  type        = string
  default     = "default"
}
