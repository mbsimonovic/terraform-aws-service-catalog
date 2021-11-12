# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "private_zones" {
  description = "A map of private Route 53 Hosted Zones. In this map, the key should be the domain name. See examples below."
  type = map(object({
    # An optional, arbitrary comment to attach to the private Hosted Zone
    comment = string
    # The list of VPCs to associate with the private Hosted Zone. You must provide at least one VPC in this list.
    vpcs = list(object({
      # The ID of the VPC.
      id = string
      # The region of the VPC. If null, defaults to the region configured on the provider.
      region = string
    }))
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
  #         vpcs = [{
  #           id = "19233983937"
  #           region = null
  #         }]
  #         tags = {
  #             CanDelete = true
  #         }
  #         force_destroy = true
  #     }
  #     "database.com" = {
  #         comment = "This is prod - don't delete!"
  #         vpcs = [{
  #           id = "129734967447"
  #           region = null
  #         }]
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
  type        = any
  # Following are supported keys in the object:
  # An arbitrary comment to attach to the public Hosted Zone
  #   comment = string
  #
  # A mapping of tags to assign to the public Hosted Zone
  #   tags = map(string)
  #
  # Whether to destroy all records (possibly managed ouside of Terraform) in the zone when destroying the zone
  #   force_destroy = bool
  #
  # Subject alternative names are a set of domains that you want the issued certificate to also cover. These can be
  # additional (sites, IP addresses and common names). You can also use this field to create a wildcard certificate.
  # For example, if your domain is example.com, add "*.example.com" as a subject alternative name in order to request
  # a certificate that will protect both the apex domain name and the first-level subdomains such as mail.example.com
  # and test.example.com
  #   subject_alternative_names = list(string)
  #
  # If the zone already exists, and you just want to provision a wildcard certificate for it, you can set
  # created_outside_terraform to true, in which case the existing zone will have its ID looked up programmatically
  # and DNS validation records required for certificate validation will be written to it
  #   created_outside_terraform = bool
  #
  # If created_outside_terraform is true, look up the existing hosted zone using this domain name. If not specified, uses the key in this map as the domain name.
  # This var is useful when the domain in the cert is different than the domain in the hosted zone.
  #   hosted_zone_domain_name = string
  #
  # Tags to use to filter the Route 53 Hosted Zones that might match the hosted zone's name (use if you have multiple public hosted zones with the same name)
  #   base_domain_name_tags = map(string)
  #
  # Whether or not to create a Route 53 DNS record for use in validating the issued certificate. You may want to set this to false if you are not using Route 53 as your DNS provider.
  #   create_verification_record = bool
  #
  # Whether or not to attempt to verify the issued certificate via DNS entries automatically created via Route 53 records. You may want to set this to false on your certificate inputs if you are not using Route 53 as your DNS provider.
  #   verify_certificate = bool
  #
  # Whether or not to create ACM TLS certificates for the domain. When true, Route53 certificates will automatically be
  # created for the root domain. Defaults to true.
  #   provision_certificates = bool
  #
  # If this is a subdomain of an existing hosted zone, set this value to the ID of the public hosted zone for the parent
  # domain. When this value is set, this module will create the NS records in the parent hosted zone for this subdomain
  # so that the newly created hosted zone will be used to resolve domains for the subdomain. Note that the records are
  # only created if created_outside_terraform is false.
  #   parent_hosted_zone_id = string
  #
  # Create the following subdomain entries on the domain. Use this for managing records that are not associated with any
  # terraform module, like MX and TXT domains.
  # Map keys are the relevant subdomain record you wish to create.
  #   subdomains = map(object({
  #     # The record type. Valid values are A, AAAA, CAA, CNAME, DS, MX, NAPTR, NS, PTR, SOA, SPF, SRV and TXT.
  #     type = string
  #     # The TTL of the record.
  #     ttl = number
  #     # A string list of records. To specify a single record value longer than 255 characters such as a TXT record for
  #     # DKIM, add \"\" inside the Terraform configuration string (e.g. "first255characters\"\"morecharacters").
  #     records = list(string)
  #   }))
  #
  # Create the following apex records on the domain. Use this for managing records that are not associated with any
  # terraform module, like MX and TXT domains.
  #   apex_records = list(object({
  #     # The record type. Valid values are A, AAAA, CAA, CNAME, DS, MX, NAPTR, NS, PTR, SOA, SPF, SRV and TXT.
  #     type = string
  #     # The TTL of the record.
  #     ttl = number
  #     # A string list of records. To specify a single record value longer than 255 characters such as a TXT record for
  #     # DKIM, add \"\" inside the Terraform configuration string (e.g. "first255characters\"\"morecharacters").
  #     records = list(string)
  #   }))
  #

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
  #         create_verification_record = true
  #         verify_certificate        = true
  #         base_domain_name_tags = {
  #             original = true
  #         }
  #         apex_records = [
  #           {
  #             type    = "MX"
  #             ttl     = 3600
  #             records = [
  #               "1 mx.example.com."
  #               "5 mx1.example.com."
  #               "10 mx2.example.com."
  #             ]
  #           },
  #           {
  #             type    = "SPF"
  #             ttl     = 3600
  #             records = [
  #               "v=spf1 include:_spf.example.com ~all"
  #             ]
  #           },
  #           {
  #             type    = "TXT"
  #             ttl     = 3600
  #             records = [
  #               "v=spf1 include:_spf.example.com ~all"
  #             ]
  #           }
  #         ]
  #         subdomains = {
  #           txt-test = {
  #             type    = "txt"
  #             ttl     = 3600
  #             records = ["hello-world"]
  #           }
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
  type        = any
  # Following are supported keys in the object:
  # Subject alternative names are a set of domains that you want the issued certificate to also cover. These can be
  # additional (sites, IP addresses and common names). You can also use this field to create a wildcard certificate.
  # For example, if your domain is example.com, add "*.example.com" as a subject alternative name in order to request
  # a certificate that will protect both the apex domain name and the first-level subdomains such as mail.example.com
  # and test.example.com
  #  subject_alternative_names = list(string)
  #
  # If the zone already exists, and you just want to provision a wildcard certificate for it, you can set
  # created_outside_terraform to true, in which case the existing zone will have its ID looked up programmatically
  # and DNS validation records required for certificate validation will be written to it
  #  created_outside_terraform = bool
  #
  # If created_outside_terraform is true, look up the existing hosted zone using this domain name. If not specified, uses the key in this map as the domain name.
  # This var is useful when the domain in the cert is different than the domain in the hosted zone.
  #  hosted_zone_domain_name = string
  #
  # Tags to use to filter the Route 53 Hosted Zones that might match the hosted zone's name (use if you have multiple public hosted zones with the same name)
  #  base_domain_name_tags = map(string)
  #
  # A user friendly description for the namespace.
  #  description = string

  # Whether or not to create a Route 53 DNS record for use in validating the issued certificate. You may want to set this to false if you are not using Route 53 as your DNS provider.
  #  create_verification_record = bool
  #
  # Whether or not to attempt to verify the issued certificate via DNS entries automatically created via Route 53 records. You may want to set this to false on your certificate inputs if you are not using Route 53 as your DNS provider.
  #  verify_certificate = bool
  #
  # Whether or not to create ACM TLS certificates for the domain. When true, Route53 certificates will automatically be
  # created for the root domain. Defaults to true.
  #  provision_certificates = bool

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
