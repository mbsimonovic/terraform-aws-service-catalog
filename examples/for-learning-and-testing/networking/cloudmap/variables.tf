# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which to deploy the resources. This variable will be passed to the provider's region parameter."
  type        = string
  default     = "eu-west-1"
}

variable "service_discovery_public_namespaces" {
  description = "A map of domain names to configurations for setting up a new public namespace in AWS Cloud Map. Note that the domain name must be registered with Route 53."
  type = map(object({

    # Subject alternative names are a set of domains that you want the issued certificate to also cover. These can be
    # additional (sites, IP addresses and common names). You can also use this field to create a wildcard certificate.
    # For example, if your domain is example.com, add "*.example.com" as a subject alternative name in order to request
    # a certificate that will protect both the apex domain name and the first-level subdomains such as mail.example.com
    # and test.example.com. See the examples below for all possible scenarios.
    subject_alternative_names = list(string)
    # If the zone already exists, and you just want to provision a wildcard certificate for it, you can set created_outside_terraform to true in which case the
    # existing zone will have its ID looked up programmatically and DNS validation records required for certificate validation will be written to it
    created_outside_terraform = bool
    # If created_outside_terraform is true, look up the existing hosted zone uising this domain name. If not specified, uses the key in this map as the domain name.
    # This var is useful when the domain in the cert is different than the domain in the hosted zone.
    hosted_zone_domain_name = string
    # A user friendly description for the namespace.
    description = string
  }))

  # Default to empty map so that public namespaces are only created when requested.
  default = {}
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

# ---------------------------------------------------------------------------------------------------------------------
# TEST INSTANCE PARAMETERS
# These variables are configuration parameters for the test EC2 instance that is registered to one of the namespaces.
# ---------------------------------------------------------------------------------------------------------------------

variable "test_instance_namespace" {
  description = "Namespace name to associate the test EC2 instance with. There should be an entry for this namespace in service_discovery_public_namespaces or service_discovery_private_namespaces."
  type        = string
  default     = null
}

variable "test_instance_name" {
  description = "Name to use for the test EC2 instance that will be associated."
  type        = string
  default     = "test-cloud-map"
}

variable "test_instance_vpc_subnet_id" {
  description = "The ID of the VPC Subnet to launch the test instance in. This should be a public subnet."
  type        = string
  default     = null
}

variable "test_instance_key_pair" {
  description = "AWS EC2 key pair to associate with the test EC2 instance."
  type        = string
  default     = null
}
