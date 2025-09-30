resource "aws_kms_key" "kms" {
  description             = "Key for ECR"
  enable_key_rotation     = true
  deletion_window_in_days = 20
}