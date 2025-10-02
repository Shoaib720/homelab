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
generate "provider" {
  path      = "provider.generated.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  terraform {
    required_version = ">= 1.5.0"
  }
  provider "aws" {
    region = "ap-south-1"
  }
EOF
}

locals {
  # Only base (environment-agnostic) values here.
  base_tags = {
    Owner = "shoaib"
    Project = "homelab"
  }
}