# In this file, we pull in dependencies that are convenient for testing / learning, but not what you'd use in
# production.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_route53_zone" "jenkins" {
  name = "${var.base_domain_name}."
  tags = var.base_domain_name_tags
}

locals {
  # The ids param is a set, so to consistently extract the same item, we convert to a list and sort first.
  subnet_for_jenkins = sort(tolist(data.aws_subnet_ids.default.ids))[0]
}