ui = true
disable_mlock = true
api_addr = "https://vault.deploywizard.in"

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

storage "file" {
  path = "/vault/data"
}

seal "awskms" {
  region     = "ap-south-1"
  kms_key_id = "alias/vault-auto-unseal"
}