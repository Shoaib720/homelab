include {
  path = find_in_parent_folders("root.hcl")
}

# Pull env-specific locals (environment, common_tags) from ../terragrunt.hcl
locals {
  env_cfg = read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
}

terraform {
  source = "../../../../modules/vpc"
}

inputs = {
  name       = "nonprod"
  cidr_block = "10.0.0.0/16"
  azs        = ["ap-south-1a", "ap-south-1b"]
}