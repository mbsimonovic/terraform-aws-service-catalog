module "mock_asg_service" {
  source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/mock-asg-service?ref=mock-experiment"

  vpc_id   = var.vpc_id
  ami_id   = var.ami_id
  key_name = var.key_name

  # Settings specific to our custom ASG service
  port = 8080
  cloud_init_parts = {
    foo = {
      filename     = "custom-asg-service-cloud-init"
      content_type = "text/x-shellscript"
      content      = file("${path.module}/cloud-init.sh")
    }
  }
}