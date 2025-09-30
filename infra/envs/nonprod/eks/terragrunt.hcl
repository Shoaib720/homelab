include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  cluster_name = "homelab-nonprod"
  ecr_kms_key_id = "7efcebfa-8e31-4ff4-bcff-783fe08f54ec"
  subnet_ids   = dependency.vpc.outputs.public_subnets
  node_configs = {
    instance_type = "t3.medium"
    scaling = {
        desired = 1
        min = 1
        max = 2
    }
  }
}
