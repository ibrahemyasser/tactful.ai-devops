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
  source = "../../../modules//bastion"
}

# Dependencies
dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id              = "vpc-mock"
    public_subnet_ids   = ["subnet-mock-1", "subnet-mock-2"]
    private_subnet_ids  = ["subnet-mock-3", "subnet-mock-4"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "eks" {
  config_path = "../eks-cluster"
  
  mock_outputs = {
    cluster_id                           = "cluster-mock"
    cluster_endpoint                     = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data   = "LS0tLS1=="
    cluster_security_group_id            = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Input variables
inputs = {
  name_prefix            = "tactful-voting-prod"
  vpc_id                 = dependency.vpc.outputs.vpc_id
  private_subnet_id      = dependency.vpc.outputs.private_subnet_ids[0]
  cluster_name           = dependency.eks.outputs.cluster_id
  cluster_endpoint       = dependency.eks.outputs.cluster_endpoint
  cluster_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  eks_security_group_id  = dependency.eks.outputs.cluster_security_group_id
  
  # Production: Private bastion with SSM access only
  # To connect: aws ssm start-session --target <instance-id> --region us-east-1
  
  instance_type = "t3.small"
}
