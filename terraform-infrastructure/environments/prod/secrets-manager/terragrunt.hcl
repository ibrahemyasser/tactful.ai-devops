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
  name_prefix = "tactful-voting-prod"
  environment = "prod"
  
  # Production: longer recovery window
  recovery_window_in_days = 30
  
  tags = {
    Environment = "prod"
    Project     = "tactful-voting"
    ManagedBy   = "Terraform"
    Component   = "Secrets"
  }
}
