resource "aws_kms_key_policy" "kms_policy" {
    key_id = aws_kms_key.kms.id
    policy = jsonencode({
        "Version": "2012-10-17",
        "Id": "ecr-kms-key-policy",
        "Statement": [
            {
                "Sid": "AllowRootAccountFullAccess",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
                },
                "Action": "kms:*",
                "Resource": "*"
            },
            {
                "Sid": "AllowECRToUseKey",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecr.amazonaws.com"
                },
                "Action": [
                    "kms:Encrypt",
                    "kms:Decrypt",
                    "kms:GenerateDataKey*",
                    "kms:DescribeKey"
                ],
                "Resource": "*"
            }
        ]
    })
}