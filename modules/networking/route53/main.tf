# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A ROUTE 53 HOSTED ZONE FOR INTERNAL DNS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # Require at least 0.12.6, which added for_each support; make sure we don't accidentally pull in 0.13.x, as that may
  # have backwards incompatible changes when it comes out.

  required_version = "~> 0.12.6"

  required_providers {
    aws = "~> 2.6"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A HOSTED ZONE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_zone" "internal_services" {
  for_each = var.private_zones

  name    = each.value.name
  comment = each.value.comment

  vpc {
    vpc_id = each.value.vpc_id

  }
  force_destroy = each.value.force_destroy
}

resource "aws_route53_zone" "public_zones" {
  for_each = var.public_zones

  name    = each.value.name
  comment = each.value.comment

  vpc {
    vpc_id = each.value.vpc_id
  }

  force_destroy = each.value.force_destroy

}
