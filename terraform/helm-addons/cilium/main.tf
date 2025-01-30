# Ref Talos CLuster

# Helm Install
resource "helm_release" "cilium" {
  name = "cilium"
  chart = "cilium"
  repository = "https://helm.cilium.io/"
  version = "1.16.5"
  namespace = "kube-system"
  values = [
    file("${path.module}/files/values.yaml")
  ]
}