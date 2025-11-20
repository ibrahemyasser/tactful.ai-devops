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

dependency "secrets" {
  config_path = "../secrets-manager"
  
  mock_outputs = {
    external_secrets_role_arn = "arn:aws:iam::123456789012:role/mock-external-secrets-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  skip_outputs = true  # Optional dependency - secrets module may not exist yet
}

# Input variables
inputs = {
  cluster_name    = "tactful-voting-dev"
  cluster_version = "1.34"
  
  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  
  # Allow public access from your IP for easy development
  # Replace with your actual IP (run: curl ifconfig.me)
  endpoint_public_access = true
  public_access_cidrs    = ["0.0.0.0/0"] # Replace with "<YOUR_IP>/32"
  allowed_cidr_blocks    = []
  
  # Enable all control plane logs for dev
  cluster_log_types  = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days = 7
  
  # Node groups configuration
  node_groups = {
    general = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
      labels = {
        role = "general"
      }
    }
  }
  
  # External Secrets Operator Pod Identity (from secrets-manager module)
  # This will be empty on first apply, run secrets-manager first, then re-apply EKS
  external_secrets_role_arn = try(dependency.secrets.outputs.external_secrets_role_arn, "")
}
