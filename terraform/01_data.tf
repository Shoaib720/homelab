data "aws_ami" "latest_homelab" {
  owners      = ["self"]  # or your AWS account ID
  most_recent = true

  filter {
    name   = "name"
    values = ["homelab-ami-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}