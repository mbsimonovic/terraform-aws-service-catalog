# ----------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ECS CLUSTER
# ----------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region 

  version = "2.63.0"
}

module "ecs_cluster" {
  # When using these modules in your own repos, you will need to use a Git URL with a ref attribute that pins you 
  # to a specific version of the modules, such as the following example: 
  # source = "git::git@github.com:gruntwork-io/aws-service-catalog.git//modules/services/ecs-cluster?ref=1.0.8"
  source = "../../../../modules/services/ecs-cluster"

  cluster_name = var.cluster_name
  cluster_instance_ami = var.cluster_instance_ami_id
  cluster_instance_type = "t3.small"
  

  # For this simple example, use a regular keypair instead of ssh-grunt 
  cluster_instance_keypair_name = var.keypair_name 
  enable_ssh_grunt = false 

  vpc_id = module.vpc.vpc_id 
  vpc_subnet_ids = module.vpc.vpc_subnet_ids

} 
  
# ----------------------------------------------------------------------------------------------------------------------
# CREATE A VPC 
# ----------------------------------------------------------------------------------------------------------------------

module "vpc" {
  source = "../../../../modules/networking/vpc"

  aws_region = var.aws_region
  cidr_block = "10.0.0.0/16"
  num_nat_gateways = 1 
  vpc_name = var.cluster_name
  create_flow_logs = false 
}


