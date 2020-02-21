source "amazon-ebs" "ubuntu_ami" {
  ami_name        = "jenkins-server-{{isotime | clean_resource_name}}"
  ami_description = "An Ubuntu AMI that runs Jenkins."

  # Build the AMI in the region the user specifies
  region = var.aws_region

  # Optionally copy the AMI to other AWS regions
  ami_regions = var.copy_to_regions

  # Use a small, cheap instance type to build the AMI. Once built, you can run the AMI on any other instance type
  instance_type = "t2.micro"

  # Look up the latest Ubuntu base AMI from Canonical
  source_ami_filter {
    owners      = ["099720109477"]
    most_recent = true

    filters {
      virtualization-type = "hvm"
      architecture        = "x86_64"
      name                = "*ubuntu-bionic-18.04-amd64-server-*"
      root-device-type    = "ebs"
    }
  }

  # The default user we can SSH to for the Ubuntu AMI
  ssh_username = "ubuntu"

  # Optionally encrypt the root volume
  encrypt_boot = var.encrypt_boot

  # Optionally share the AMI with other AWS accounts
  ami_users = var.ami_users
}
