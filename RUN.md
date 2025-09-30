# Commands to provision

```bash
# Create Namespaces
k create ns nonprod
k create ns traefik

helm upgrade --install traefik traefik/traefik \                                  
  --namespace traefik \
  -f traefik-values.yaml

k apply -f platform-apps/dashboard/ -n nonprod

helm upgrade --install vault hashicorp/vault -n nonprod -f values.yaml

helm upgrade --install traefik traefik/traefik -n traefik -f values.yaml
```