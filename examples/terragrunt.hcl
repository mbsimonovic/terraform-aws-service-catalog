generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "random" {}

provider "aws" {
  region = "eu-west-1"
}
EOF
}

remote_state {
  backend = "local"
  config = {
    path = "foo.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}