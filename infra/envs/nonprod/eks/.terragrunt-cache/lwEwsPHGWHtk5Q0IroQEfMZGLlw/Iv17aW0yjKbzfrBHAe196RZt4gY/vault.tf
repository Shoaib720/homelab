# resource "aws_iam_policy" "vault_kms_unseal" {
#   name        = "VaultKMSUnsealPolicy"
#   description = "Allow Vault pods to use AWS KMS for auto-unseal"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = [
#           "kms:Encrypt",
#           "kms:Decrypt",
#           "kms:DescribeKey",
#           "kms:GenerateDataKey*"
#         ]
#         Resource = data.aws_kms_key.by_alias.arn
#       }
#     ]
#   })
# }

# data "aws_iam_policy_document" "vault_irsa_assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.this.arn]
#     }

#     actions = ["sts:AssumeRoleWithWebIdentity"]

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
#       values   = ["system:serviceaccount:${var.vault_namespace}:${var.vault_service_account}"]
#     }
#   }
# }

# resource "aws_iam_role" "vault_irsa" {
#   name               = "VaultKMSUnsealRole"
#   assume_role_policy = data.aws_iam_policy_document.vault_irsa_assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "vault_kms_attach" {
#   role       = aws_iam_role.vault_irsa.name
#   policy_arn = aws_iam_policy.vault_kms_unseal.arn
# }
