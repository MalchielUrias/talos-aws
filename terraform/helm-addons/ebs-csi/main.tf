# Ref Talos CLuster

# Helm Install
resource "helm_release" "ebs" {
  name = "ebs-csi"
  chart = "aws-ebs-csi-driver"
  repository = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver"
  version = "2.38.1"
  namespace = "kube-system"
  values = [
    file("${path.module}/files/values.yaml")
  ]
}