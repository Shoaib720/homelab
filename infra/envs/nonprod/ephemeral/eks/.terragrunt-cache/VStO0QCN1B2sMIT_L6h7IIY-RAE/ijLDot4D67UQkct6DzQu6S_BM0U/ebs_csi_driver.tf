resource "aws_iam_role" "ebs_csi_driver" {
  assume_role_policy = data.aws_iam_policy_document.example_assume_role_policy.json
  name               = "AmazonEKS_EBS_CSI_DriverRole"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_attach" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.48.0-eksbuild.2"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts_on_update = "OVERWRITE"
}