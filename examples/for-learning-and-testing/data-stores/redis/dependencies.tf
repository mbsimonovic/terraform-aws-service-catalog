# In this file, we pull in dependencies that are convenient for testing / learning, but not what you'd use in
# production.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
