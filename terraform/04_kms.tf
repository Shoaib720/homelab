resource "aws_kms_key" "vault_unseal" {
  description             = "Vault Auto-Unseal KMS Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/vault-auto-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
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
        Resource = aws_kms_key.vault_unseal.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_vault_kms_policy" {
  role       = aws_iam_role.homelab_server_role.name
  policy_arn = aws_iam_policy.vault_kms_policy.arn
}