output "instance_public_ip" {
  value = aws_instance.lab_server.public_ip
}

output "instance_id" {
  value = aws_instance.lab_server.id
}