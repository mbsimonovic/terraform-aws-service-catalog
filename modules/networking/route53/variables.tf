# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "private_zones" {
  description = "A map of private Route 53 Hosted Zones. In this map, the key should be the domain name. See examples below."
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
  # Allow empty maps to be passed by default - since we sometimes define only public zones or only private zones in a given module call
  default = {}
}

variable "public_zones" {
  description = "A map of public Route 53 Hosted Zones. In this map, the key should be the domain name. See examples below."
  type = map(object({
    # If the public zone already exists, as is often the case when dealing with public zones bootstrapped by Route53, 
    # you can pass the zone_id. Verification DNS records for certificate issuance will be written to the zone specified by 
    # the Zone ID you supply. If you leave this empty, a new public hosted zone will be created instead
    zone_id = string
    # An optional, arbitrary comment to attach to the public Hosted Zone
    comment = string
    # A mapping of tags to assign to the public Hosted Zone 
    tags = map(string)
    # (Optional) Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
    # (Optional) If set to true, automatically order and verify a wildcard certificate via ACM for this domain
    provision_wildcard_certificate = bool
  }))
  # Allow empty maps to be passed by default - since we sometimes define only public zones or only private zones in a given module call
  default = {}
}

/*

Example inputs: 

public_zones = {
    "example.com" = {
        # Setting the zone_id specifies that this is an existing zone, which will often be the case
        # if, for example, you register a domain via Route53. In this case, AWS will automatically create 
        # a public hosted zone for your domain, so you only need to supply its ID
        zone_id = ""
        comment = "You can add arbitrary text here"
        tags = {
            Foo = "bar" 
        }
        force_destroy = true 
        provision_wildcard_certificate = true
    }
    "company-name.com" = {
        comment = "This is another comment"
        tags = {
           Bar = "baz"
        }
    }
}

private_zones = {
    "backend.com" = {
        comment = "Use for arbitrary comments"
        vpc_id = 19233983937
        tags = {
            CanDelete = true 
        }
        force_destroy = true 
    }
    "database.com" = {
        comment = "This is prod - don't delete!"
        vpc_id = 129734967447
        tags = {
            Application = "redis" 
            Team = "apps"
        }
        force_destroy = false
    }
}

 */
