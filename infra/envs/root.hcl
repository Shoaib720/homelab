remote_state {
  backend = "s3"
  config = {
    bucket         = "all-project-tfstates-07062025"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    use_lockfile = true
  }
}

# Provider config (shared everywhere)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "ap-south-1"
}
EOF
}

# Common inputs (tags, naming, etc.)
locals {
  common_tags = {
    Owner       = "shoaib"
    Environment = basename(dirname(path_relative_to_include()))
  }
}

inputs = {
  tags = local.common_tags
}
