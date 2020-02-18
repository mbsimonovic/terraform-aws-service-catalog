terraform {
  source = "../../modules/mock-asg-service"
}

dependency "vpc" {
  config_path = "../mock-vpc"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
  ami_id = "ami-abcd1234"

  cloud_init_parts = {
    foo = {
      content_type = "text/x-shellscript"
      content      = <<EOF
#!/usr/bin/env bash
echo 'Hello, World custom!' > /home/ubuntu/test-custom.txt
EOF
    }
  }

  key_name = "jim-brikman"
}