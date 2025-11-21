terraform {
  source = "../../../modules//github-oidc"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  environment = "prod"
}
