# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "private_zones" {
  type = map(object({
    name          = string
    comment       = string
    vpc_id        = string
    tags          = map(string)
    force_destroy = bool
  }))
}

variable "public_zones" {
  type = map(object({
    name          = string
    comment       = string
    vpc_id        = string
    tags          = map(string)
    force_destroy = bool
  }))
}
