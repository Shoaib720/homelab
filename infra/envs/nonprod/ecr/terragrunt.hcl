include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/ecr"
}

inputs = {
  configs = {
    repositories = [
      {
        name = "homelab-dashboard"
        image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"
        exclusion_filters = [
          {
            filter_type = "WILDCARD"
            filter = "latest"
          }
        ]
        enable_image_scanning = true
      }
    ]
  }
}
