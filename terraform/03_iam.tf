resource "aws_iam_role" "homelab_server_role" {
  name = "homelab-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "vault_kms_policy" {
  name = "VaultKMSAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = data.aws_kms_key.vault_kms_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_vault_kms_policy" {
  role       = aws_iam_role.homelab_server_role.name
  policy_arn = aws_iam_policy.vault_kms_policy.arn
}

resource "aws_iam_instance_profile" "homelab_instance_profile" {
  name = "homelab-server-instance-profile"
  role = aws_iam_role.homelab_server_role.name
}