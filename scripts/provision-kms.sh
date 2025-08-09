#!/bin/bash
set -euo pipefail

AWS_REGION="${1:-ap-south-1}"
ALIAS_NAME="${2:-alias/vault-unseal}"

echo "[INFO] Region     : $AWS_REGION"
echo "[INFO] Alias Name : $ALIAS_NAME"

# Check if alias exists
EXISTING_KEY_ID=$(aws kms list-aliases \
  --region "$AWS_REGION" \
  --query "Aliases[?AliasName=='$ALIAS_NAME'].TargetKeyId | [0]" \
  --output text)

if [[ "$EXISTING_KEY_ID" != "None" && -n "$EXISTING_KEY_ID" ]]; then
  echo "[INFO] Alias already exists and points to KeyId: $EXISTING_KEY_ID"
else
  echo "[INFO] Creating new KMS key..."
  KEY_ID=$(aws kms create-key \
    --region "$AWS_REGION" \
    --description "Vault auto-unseal key" \
    --key-usage ENCRYPT_DECRYPT \
    --key-spec SYMMETRIC_DEFAULT \
    --query 'KeyMetadata.KeyId' \
    --output text)

  echo "[INFO] Created KeyId: $KEY_ID"
  echo "[INFO] Creating alias: $ALIAS_NAME"
  aws kms create-alias \
    --region "$AWS_REGION" \
    --alias-name "$ALIAS_NAME" \
    --target-key-id "$KEY_ID"

  echo "[INFO] Done. KeyId: $KEY_ID"
fi
