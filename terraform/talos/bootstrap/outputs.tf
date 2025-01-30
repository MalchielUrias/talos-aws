output "kubeconfig" {
  value = resource.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
}