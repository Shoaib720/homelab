locals {
  oidc_url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  oidc_host = replace(local.oidc_url, "https://", "")
}