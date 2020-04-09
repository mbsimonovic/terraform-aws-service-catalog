# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "private_zones" {
  description = "A map of private Route 53 Hosted Zones"
  type = map(object({
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
    # An optional, arbitrary comment to attach to the public Hosted Zone
    comment = string
    # The ID of the VPC to associate with the public Hosted Zone
    vpc_id = string
    # A mapping of tags to assign to the public Hosted Zone 
    tags = map(string)
    # (Optional) Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
    # (Optional) If set to true, automatically order and verify a wildcard certificate via ACM for this domain
    provision_wildcard_certificate = bool
  }))
}

/*

Example inputs: 

public_zones = {
    "example.com" = {
        comment = "this is prod don't delete"
        vpc_id = 19233983937
        tags = {
            Isprod = true 
            ShouldDelete = false 
        }
        force_destroy = true 
        provision_wildcard_certificate = true
    }
    "company-name.com" = {
        comment = "this is also sort of prod"
        vpc_id = 129734967447
        tags = {
            Isprod = "Kinda" 
            ShouldDelete = "Shrug" 
        }
    }
}
private_zones = {
    "backend.com" = {
        comment = "this is prod don't delete"
        vpc_id = 19233983937
        tags = {
            Isprod = true 
            ShouldDelete = false 
        }
        force_destroy = true 
        provision_wildcard_certificate = true
    }
    "database.com" = {
        comment = "this is also sort of prod"
        vpc_id = 129734967447
        tags = {
            Isprod = "Kinda" 
            ShouldDelete = "Shrug" 
        }
        provision_wildcard_certificate = true 
    }
}

 */
