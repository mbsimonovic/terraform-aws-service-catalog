# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "private_zones" {
  description = "A map of private Route 53 Hosted Zones"
  type = map(object({
    # Name of the private Route 54 Hosted Zone to be created
    # e.g: gruntwork-example.xyz 
    name = string
    # An optional, arbitrary comment to attach to the private Hosted Zone
    comment = string
    # The ID of the VPC to associate with the private Hosted Zone
    vpc_id = string
    # A mapping of tags to assign to the private Hosted Zone 
    tags = map(string)
    # (Optional) Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
  }))
}

variable "public_zones" {
  description = "A map of public Route 53 Hosted Zones"
  type = map(object({
    # Name of the public Route 54 Hosted Zone to be created
    # e.g: gruntwork-example.com
    name = string
    # An optional, arbitrary comment to attach to the public Hosted Zone
    comment = string
    # The ID of the VPC to associate with the public Hosted Zone
    vpc_id = string
    # A mapping of tags to assign to the public Hosted Zone 
    tags = map(string)
    # (Optional) Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
  }))
}