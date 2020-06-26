# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MODULE DEPENDENCIES LOOKED UP WITH DATA SOURCES
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Look up the AMI to use for the openvpn server, if the AMI ID is not passed in directly
data "aws_ami" "openvpn" {
  count = local.use_ami_lookup ? 1 : 0

  most_recent = true
  owners      = var.ami_filters.owners

  dynamic "filter" {
    for_each = var.ami_filters.filters

    content {
      name   = each.value.name
      values = each.value.values
    }
  }
}

locals {
  use_ami_lookup = var.ami == null
}
