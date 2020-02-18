resource "random_pet" "example" {
  keepers = {
    amm_id = var.ami_id
    vpc_id = var.vpc_id
  }

  prefix = "ami-"
}

locals {
  # Default cloud init script for this module
  cloud_init = {
    content_type = "text/x-shellscript"
    content      = "echo 'Hello, World!'"
  }

  # Merge in all the cloud init scripts the user has passed in
  cloud_init_parts = merge({ default : local.cloud_init }, var.cloud_init_parts)
}

data "template_cloudinit_config" "cloud_init" {
  gzip          = false
  base64_encode = false

  dynamic "part" {
    for_each = local.cloud_init_parts

    content {
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}