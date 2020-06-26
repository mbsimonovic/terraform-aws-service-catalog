# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# MODULE DEPENDENCIES LOOKED UP WITH DATA SOURCES
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Look up the AMI to use for self managed workers, if the AMI ID is not passed in directly
data "aws_ami" "worker" {
  count = local.use_ami_lookup ? 1 : 0

  most_recent = true
  owners      = var.cluster_instance_ami_filters.owners

  dynamic "filter" {
    for_each = var.cluster_instance_ami_filters.filters

    content {
      name   = each.value.name
      values = each.value.values
    }
  }
}

locals {
  use_ami_lookup = var.cluster_instance_ami == null && length(var.autoscaling_group_configurations) > 0
}
