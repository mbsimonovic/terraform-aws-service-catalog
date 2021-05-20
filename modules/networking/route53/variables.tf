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
    # Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
  }))
  # Allow empty maps to be passed by default - since we sometimes define only public zones or only private zones in a given module call
  default = {}

  # Example:
  #
  # private_zones = {
  #     "backend.com" = {
  #         comment = "Use for arbitrary comments"
  #         vpc_id = 19233983937
  #         tags = {
  #             CanDelete = true
  #         }
  #         force_destroy = true
  #     }
  #     "database.com" = {
  #         comment = "This is prod - don't delete!"
  #         vpc_id = 129734967447
  #         tags = {
  #             Application = "redis"
  #             Team = "apps"
  #         }
  #         force_destroy = false
  #     }
  # }

}

variable "public_zones" {
  description = "A map of public Route 53 Hosted Zones. In this map, the key should be the domain name. See examples below."
  type = map(object({
    # An arbitrary comment to attach to the public Hosted Zone
    comment = string
    # A mapping of tags to assign to the public Hosted Zone
    tags = map(string)
    # Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
    force_destroy = bool
    # Subject alternative names are a set of domains that you want the issued certificate to also cover. These can be
    # additional (sites, IP addresses and common names). You can also use this field to create a wildcard certificate.
    # For example, if your domain is example.com, add "*.example.com" as a subject alternative name in order to request
    # a certificate that will protect both the apex domain name and the first-level subdomains such as mail.example.com
    # and test.example.com
    subject_alternative_names = list(string)
    # If the zone already exists, and you just want to provision a wildcard certificate for it, you can set
    # created_outside_terraform to true, in which case the existing zone will have its ID looked up programmatically
    # and DNS validation records required for certificate validation will be written to it
    created_outside_terraform = bool
    # If created_outside_terraform is true, look up the existing hosted zone uising this domain name. If not specified, uses the key in this map as the domain name.
    # This var is useful when the domain in the cert is different than the domain in the hosted zone.
    hosted_zone_domain_name = string
    # Tags to use to filter the Route 53 Hosted Zones that might match the hosted zone's name (use if you have multiple public hosted zones with the same name)
    base_domain_name_tags = map(string)
    # Whether or not to create a Route 53 DNS record for use in validating the issued certificate. You may want to set this to false if you are not using Route 53 as your DNS provider.
    create_verification_record = bool
    # Whether or not to attempt to verify the issued certificate via DNS entries automatically created via Route 53 records. You may want to set this to false on your certificate inputs if you are not using Route 53 as your DNS provider.
    verify_certificate = bool
  }))
  # Allow empty maps to be passed by default - since we sometimes define only public zones or only private zones in a given module call
  default = {}

  # Example: Request a certificate protecting only the apex domain
  #
  # public_zones = {
  #     "example.com" = {
  #         comment = "You can add arbitrary text here"
  #         tags = {
  #             Foo = "bar"
  #         }
  #         force_destroy = true
  #         subject_alternative_names = []
  #         created_outside_terraform = true
  #         create_verification_record= true
  #         verify_certificate        = true
  #         base_domain_name_tags = {
  #             original = true
  #         }
  #     }
  # }
  #
  # Example: Request a wildcard certificate that does NOT protect the apex domain:
  #
  # public_zones = {
  #     "*.example.com = {
  #           comment = ""
  #           tags = {}
  #           force_destroy = true
  #           subject_alternative_names = []
  #           base_domain_name_tags = {}
  #           create_verification_record = true
  #           verify_certificate         = true
  #     }
  # }
  #
  # Example: Request a wildcard certificate that covers BOTH the apex and first-level subdomains
  #
  # public_zones = {
  #     "example.com" = {
  #         comment = ""
  #         tags = {}
  #         force_destroy = false
  #         subject_alternative_names = ["*.example.com"]
  #         base_domain_name_tags = {}
  #         create_verification_record = true
  #         verify_certificate         = true
  #     }
  # }
}

variable "service_discovery_public_namespaces" {
  description = "A map of domain names to configurations for setting up a new public namespace in AWS Cloud Map. Note that the domain name must be registered with Route 53."
  type = map(object({
    # Subject alternative names are a set of domains that you want the issued certificate to also cover. These can be
    # additional (sites, IP addresses and common names). You can also use this field to create a wildcard certificate.
    # For example, if your domain is example.com, add "*.example.com" as a subject alternative name in order to request
    # a certificate that will protect both the apex domain name and the first-level subdomains such as mail.example.com
    # and test.example.com
    subject_alternative_names = list(string)
    # If the zone already exists, and you just want to provision a wildcard certificate for it, you can set
    # created_outside_terraform to true, in which case the existing zone will have its ID looked up programmatically
    # and DNS validation records required for certificate validation will be written to it
    created_outside_terraform = bool
    # If created_outside_terraform is true, look up the existing hosted zone uising this domain name. If not specified, uses the key in this map as the domain name.
    # This var is useful when the domain in the cert is different than the domain in the hosted zone.
    hosted_zone_domain_name = string
    # A user friendly description for the namespace.
    description = string
    # Whether or not to create a Route 53 DNS record for use in validating the issued certificate. You may want to set this to false if you are not using Route 53 as your DNS provider.
    create_verification_record = bool
    # Whether or not to attempt to verify the issued certificate via DNS entries automatically created via Route 53 records. You may want to set this to false on your certificate inputs if you are not using Route 53 as your DNS provider.
    verify_certificate = bool
  }))

  # Default to empty map so that public namespaces are only created when requested.
  default = {}
  # Example: Request a certificate protecting only the apex domain
  #
  # service_discovery_public_namespaces = {
  #     "example.com" = {
  #         subject_alternative_names = []
  #         create_verification_record = true
  #         verify_certificate         = true
  #     }
  # }
  #
  # Example: Request a wildcard certificate that does NOT protect the apex:
  #
  # service_discovery_public_namespaces = {
  #     "*.example.com" = {
  #           subject_alternative_names = []
  #           create_verification_record = true
  #           verify_certificate         = true
  #     }
  # }
  #
  # Example: Request a wildcard certificate that covers BOTH the apex and first-level subdomains
  #
  # service_discovery_public_namespaces = {
  #     "example.com" = {
  #         subject_alternative_names = ["*.example.com"]
  #         create_verification_record = true
  #         verify_certificate         = true
  #     }
  # }
}

variable "service_discovery_private_namespaces" {
  description = "A map of domain names to configurations for setting up a new private namespace in AWS Cloud Map."
  type = map(object({
    # The ID of the VPC where the private hosted zone is restricted to.
    vpc_id = string

    # A user friendly description for the namespace
    description = string
  }))

  # Default to empty map so that private namespaces are only created when requested.
  default = {}
}
