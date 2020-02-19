terraform {
  source = "../../../modules/mock-asg-service"
}

inputs = {
  vpc_id = "vpc-mock-id"
  ami_id = "ami-abcd1234"
  port   = 12345
}