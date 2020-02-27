# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY JENKINS IN AN ASG, WITH AN ALB, ROUTE 53 DNS ENTRY, ACM TLS CERT, AND CLOUDWATCH METRICS, LOGGING, AND ALERTS
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

module "jenkins" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mgmt/jenkins?ref=v1.0.8"
  source = "../../../../modules/mgmt/jenkins"

  name          = var.name
  instance_type = "t2.micro"
  ami           = var.ami_id
  memory        = "512m"

  # For this simple example, use a regular key pair instead of ssh-grunt
  keypair_name     = var.keypair_name
  enable_ssh_grunt = false

  # To keep this example simple, we run it in the default VPC and put everything in the same subnets. In production,
  # you'll want to use a custom VPC, with Jenkins in a private subnet and the ALB in a public subnet.
  vpc_id            = data.aws_vpc.default.id
  jenkins_subnet_id = local.subnet_for_jenkins
  alb_subnet_ids    = data.aws_subnet_ids.default.ids

  # Configure a domain name for Jenkins
  hosted_zone_id             = data.aws_route53_zone.jenkins.id
  domain_name                = "${var.jenkins_subdomain}.${var.base_domain_name}"
  acm_ssl_certificate_domain = var.acm_ssl_certificate_domain

  # To keep this example simple, we make the ALB public and allow incoming HTTP and SSH connections from anywhere. In
  # production, you'll want to use an internal ALB and limit access to trusted servers only (e.g., solely a bastion
  # host or VPN server).
  is_internal_alb                      = false
  allow_incoming_http_from_cidr_blocks = ["0.0.0.0/0"]
  allow_ssh_from_cidr_blocks           = ["0.0.0.0/0"]
}