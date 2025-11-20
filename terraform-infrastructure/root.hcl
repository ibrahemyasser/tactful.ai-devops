# Root Terragrunt Configuration
# This file defines the remote state configuration for all environments

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  
  # Extract commonly used variables
  environment = local.environment_vars.locals.environment
  aws_region  = local.environment_vars.locals.aws_region
  
  # Project naming
  project_name = "tactful-voting"
}

# Configure Terragrunt to automatically store tfstate files in S3 bucket
remote_state {
  backend = "s3"
  
  config = {
    encrypt        = true
    bucket         = "${local.project_name}-terraform-state-${local.environment}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "${local.project_name}-terraform-locks-${local.environment}"
    
    # Enable versioning for state file recovery
    s3_bucket_tags = {
      Name        = "${local.project_name}-terraform-state-${local.environment}"
      Environment = local.environment
      ManagedBy   = "terraform"
    }
    
    dynamodb_table_tags = {
      Name        = "${local.project_name}-terraform-locks-${local.environment}"
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  
  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project_name}"
      ManagedBy   = "terraform"
    }
  }
}
EOF
}

# Configure Terraform version
terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }
}
