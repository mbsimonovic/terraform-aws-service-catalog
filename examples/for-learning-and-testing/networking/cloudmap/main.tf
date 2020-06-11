# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY CLOUD MAP NAMESPACES FOR SERVICE DISCOVERY
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "aws" {
  region = var.aws_region
}

module "route53" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/networking/route53?ref=v1.2.3"
  source = "../../../../modules/networking/route53"

  service_discovery_public_namespaces  = var.service_discovery_public_namespaces
  service_discovery_private_namespaces = var.service_discovery_private_namespaces
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY AN EC2 INSTANCE TO REGISTER TO THE NAMESPACE
# The following is an example and test for how to register an EC2 instance to the Service Discovery Namespace as a
# service. This will:
# - Create a Service Discovery Service to hold all the instances for the bastion
# - Create an EC2 instance that will register itself to the Service Discovery Service using it's public IP.
# - Make sure the EC2 instance allows SSH and has IAM permissions to register itself to AWS CloudMap.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_service_discovery_service" "bastion" {
  name = var.test_instance_name

  dns_config {
    namespace_id = (
      contains(keys(module.route53.service_discovery_public_namespaces), var.test_instance_namespace)
      ? module.route53.service_discovery_public_namespaces[var.test_instance_namespace].id
      : module.route53.service_discovery_private_namespaces[var.test_instance_namespace].id
    )

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2.id
  instance_type               = "t3.micro"
  key_name                    = var.test_instance_key_pair
  subnet_id                   = var.test_instance_vpc_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.test_profile.name
  associate_public_ip_address = true
  user_data = templatefile(
    "${path.module}/user-data.sh",
    {
      aws_region = var.aws_region
      service_id = aws_service_discovery_service.bastion.id
    },
  )

  tags = {
    Name = var.test_instance_name
  }

  depends_on = [aws_iam_role_policy.register_permissions]
}

resource "aws_security_group" "bastion" {
  vpc_id = data.aws_subnet.selected.vpc_id

  # Inbound SSH from world
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.test_instance_name}-bastion"
  }
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "${var.test_instance_name}-register-permissions"
  role = aws_iam_role.register_permissions.name
}

resource "aws_iam_role" "register_permissions" {
  name               = "${var.test_instance_name}-register-permissions"
  assume_role_policy = data.aws_iam_policy_document.assume_from_ec2.json
}

resource "aws_iam_role_policy" "register_permissions" {
  name   = "${var.test_instance_name}-register-permissions"
  role   = aws_iam_role.register_permissions.id
  policy = data.aws_iam_policy_document.register_permissions.json
}
