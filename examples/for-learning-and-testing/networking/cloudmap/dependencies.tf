data "aws_iam_policy_document" "assume_from_ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "register_permissions" {
  statement {
    actions = [
      "servicediscovery:RegisterInstance",
      "route53:ChangeResourceRecordSets",
    ]
    resources = ["*"]
  }
}

data "aws_subnet" "selected" {
  id = var.test_instance_vpc_subnet_id
}

data "aws_ami" "al2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

locals {
  http_port = 8080
}
