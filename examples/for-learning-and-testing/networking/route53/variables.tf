# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which to deploy the resources. This variable will be passed to the provider's region parameter."
  type        = string
  default     = "eu-west-1"
}

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
}

variable "public_zones" {
  description = "A map of public Route 53 Hosted Zones. In this map, the key should be the domain name. See examples below."
  type = map(object({
    # An arbitrary comment to attach to the public Hosted Zone
    comment = string
    # A mapping of tags to assign to the public Hosted Zone 
    tags = map(string)
    # (Optional) Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
    # (Optional) If set to true, automatically order and verify a wildcard certificate via ACM for this domain
    provision_wildcard_certificate = bool
    # If the zone already exists, and you just want to provision a wildcard certificate for it, you can set created_outside_terraform to true, in which case the 
    # existing zone will have its ID looked up programmatically and DNS validation records required for certificate validation will be written 
    # to it 
    created_outside_terraform = bool
    # Tags to use to filter the Route 53 Hosted Zones that might match the hosted zone's name (use if you have multiple public hosted zones with the same name)
    base_domain_name_tags = map(string)
  }))
  # Allow empty maps to be passed by default - since we sometimes define only public zones or only private zones in a given module call
  default = {}
}

/*

Example inputs: 

public_zones = {
    "example.com" = {
        comment = "You can add arbitrary text here"
        tags = {
            Foo = "bar" 
        }
        force_destroy = true 
        provision_wildcard_certificate = true
        created_outside_terraform = true 
        base_domain_name_tags = {
            original = true 
        }
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
