include {
  path = find_in_parent_folders("root.hcl")
}

locals {
    # Import the root config so we can reference its locals
    root_cfg    = read_terragrunt_config(find_in_parent_folders("root.hcl"))
    
    environment = "nonprod"

    common_tags = merge(
        local.root_cfg.locals.base_tags,
        { Environment = local.environment }
    )
}
