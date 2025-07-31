data "aws_ami" "latest_homelab" {
  owners      = ["self"]  # or your AWS account ID
  most_recent = true
  name_regex       = "^homelab-ami-[0-9]{14}$"

  filter {
    name   = "name"
    values = ["homelab-ami-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}