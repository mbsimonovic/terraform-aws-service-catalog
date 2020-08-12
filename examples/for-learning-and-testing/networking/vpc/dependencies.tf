module "instance_types" {
  source = "git::git@github.com:gruntwork-io/package-terraform-utilities.git//modules/instance-type?ref=v0.2.1"

  instance_types = var.instance_types
}

data "aws_kms_key" "kms_key" {
  //   If you get an error like "AccessDeniedException: The specified KMS key does not exist or is not
  //   allowed to be used with LogGroup", you need to check if the key has the right permissions.
  //
  //  {
  //    "Sid": "AllowAccessForLogs",
  //    "Effect": "Allow",
  //    "Principal": {
  //      "Service": [
  //        "delivery.logs.amazonaws.com",
  //        "logs.{aws-region}.amazonaws.com"
  //      ]
  //    },
  //    "Action": [
  //      "kms:ReEncrypt*",
  //      "kms:GenerateDataKey*",
  //      "kms:Encrypt",
  //      "kms:DescribeKey",
  //      "kms:Decrypt",
  //      "kms:CreateGrant"
  //    ],
  //    "Resource": "*"
  //  }

  key_id = var.kms_key_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
}
