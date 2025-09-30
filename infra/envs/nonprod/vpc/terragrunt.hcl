include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name       = "nonprod"
  cidr_block = "10.0.0.0/16"
  azs        = ["ap-south-1a", "ap-south-1b"]
}