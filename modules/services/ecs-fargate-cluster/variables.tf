# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# Generally, these values won't need to be changed.
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_container_insights" {
  description = "Whether or not to enable container insights monitoring on the ECS cluster."
  type        = bool
  default     = true
}

variable "custom_tags" {
  description = "A map of custom tags to apply to the ECS Cluster. The key is the tag name and the value is the tag value."
  type        = map(string)
  default     = {}
}
