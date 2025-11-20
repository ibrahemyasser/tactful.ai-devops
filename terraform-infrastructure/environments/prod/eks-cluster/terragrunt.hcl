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
  source = "../../../modules//eks-cluster"
}

# Dependencies
dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id              = "vpc-mock"
    private_subnet_ids  = ["subnet-mock-1", "subnet-mock-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Input variables
inputs = {
  cluster_name    = "tactful-voting-prod"
  cluster_version = "1.34"
  
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  
  # Private cluster - no public access
  endpoint_public_access = false
  allowed_cidr_blocks    = []
  
  # Minimal logging for prod (cost optimization)
  cluster_log_types  = ["api", "audit"]
  log_retention_days = 30
  
  # Node groups configuration - larger for production
  node_groups = {
    general = {
      instance_types = ["m7i-flex.large"]
      min_size       = 2
      max_size       = 6
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      disk_size      = 30
      labels = {
        role = "general"
      }
    }
  }
}
