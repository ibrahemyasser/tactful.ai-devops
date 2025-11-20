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
  source = "../../../modules//secrets-manager"
}

# Input variables
inputs = {
  name_prefix = "tactful-voting-dev"
  environment = "dev"
  
  # Dev environment: shorter recovery window
  recovery_window_in_days = 7
  
  tags = {
    Environment = "dev"
    Project     = "tactful-voting"
    ManagedBy   = "Terraform"
    Component   = "Secrets"
  }
}
