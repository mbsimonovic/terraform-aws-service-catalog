data "aws_vpc" "default" {
  default = true
}

locals {
  default_vpc_id = data.aws_vpc.default.id
}
