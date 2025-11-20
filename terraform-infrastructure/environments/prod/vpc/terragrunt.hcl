   # Include root configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Include environment configuration
include "env" {
  path = find_in_parent_folders("env.hcl")
}

# Terraform source
terraform {
  source = "../../../modules//vpc"
}

# Input variables
inputs = {
  name_prefix  = "tactful-voting-prod"
  cluster_name = "tactful-voting-prod"
  
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
  
  enable_nat_gateway = true
  enable_flow_logs   = true
  
  flow_logs_retention_days = 30
}
