resource "aws_key_pair" "lab_key" {
  key_name   = "lab-key"
  public_key = file("~/.ssh/lab-kp.pub")
  #   public_key = file("${path.module}/lab-kp.pub")
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all
  }

  ingress {
    from_port   = 2222
    to_port     = 2222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Gitlab SSH port
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to all
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "lab_server" {
  ami             = data.aws_ami.latest_homelab.id
  instance_type   = "m6i.2xlarge" # older: "m6i.xlarge"
  key_name        = aws_key_pair.lab_key.key_name
  security_groups = [aws_security_group.allow_ssh.name]

  tags = {
    Name = "DevOps Lab"
  }

  provisioner "file" {
    source      = "~/.ssh/personal_github_rsa"
    destination = "/home/ubuntu/.ssh/id_rsa"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/lab-kp")
    host        = self.public_ip
  }
}