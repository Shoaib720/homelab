listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"   # enable TLS for real use
}

storage "raft" {
  path    = "/vault/file"
  node_id = "node1"
}

api_addr     = "http://homelab.local:8200"
cluster_addr = "http://homelab.local:8201"
ui           = true
