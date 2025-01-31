# # # ======= Talos Configs ========

# locals {
#   common_machine_config_patch = {
#     cluster = {
#       network = {
#         cni = {
#           name = "none"
#         }
#       }
#       proxy = {
#         disabled = true
#       }
#       externalCloudProvider = {
#         enabled = true
#       }
#       apiServer = {
#         extraArgs = {
#           cloud-provider = "external"
#         }
#       }
#       controllerManager = {
#         extraArgs = {
#           cloud-provider = "external"
#         }
#       }
#     }
#     machine = {
#       kubelet = {
#         extraArgs = {
#           cloud-provider = "external"
#         }
#         registerWithFQDN = true
#       }
#     }
#   }
# }

# resource "talos_machine_secrets" "this" {}

# data "talos_client_configuration" "this" {
#   cluster_name         = var.name
#   client_configuration = talos_machine_secrets.this.client_configuration
#   endpoints            = [ "https://kubeapi.kubecounty.com" ] 
# }

# resource "local_file" "talosconfig" {
#   content  = nonsensitive(data.talos_client_configuration.this.talos_config)
#   filename = "talosconfig"
# }

# data "talos_machine_configuration" "controlplane" {
#   cluster_name       = var.name
#   cluster_endpoint   = "https://kubeapi.kubecounty.com"
#   machine_type       = "controlplane"
#   machine_secrets    = talos_machine_secrets.this.machine_secrets
#   kubernetes_version = var.kubernetes_version
#   talos_version      = talos_machine_secrets.this.talos_version
#   docs               = false
#   examples           = false
#   config_patches = [
#     yamlencode(local.common_machine_config_patch)
#   ]
# }

# resource "local_file" "controlplane_config" {
#   content  = data.talos_machine_configuration.controlplane.machine_configuration
#   filename = "control-plane.yaml"
# }

# data "talos_machine_configuration" "worker" {
#   cluster_name       = var.name
#   cluster_endpoint   = "https://kubeapi.kubecounty.com"
#   machine_type       = "worker"
#   machine_secrets    = talos_machine_secrets.this.machine_secrets
#   kubernetes_version = var.kubernetes_version
#   talos_version      = talos_machine_secrets.this.talos_version
#   docs               = false
#   examples           = false
#   config_patches = [
#     yamlencode(local.common_machine_config_patch)
#   ]
# }

# resource "local_file" "worker_config" {
#   content  = data.talos_machine_configuration.worker.machine_configuration
#   filename = "worker.yaml"
# }

# # resource "talos_machine_configuration_apply" "controlplane" {

# #   client_configuration        = talos_machine_secrets.this.client_configuration
# #   machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
# #   endpoint                    = data.aws_instance.master_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].public_ip
# #   node                        = data.aws_instance.master_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].private_ip
# # }

# # resource "talos_machine_configuration_apply" "worker_group" {

# #   client_configuration        = talos_machine_secrets.this.client_configuration
# #   machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
# #   node                        = data.aws_instance.worker_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].public_ip
# # }

# resource "talos_machine_bootstrap" "talos_bootstrap" {
#   client_configuration = talos_machine_secrets.this.client_configuration
#   endpoint                 = data.aws_instance.master_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].public_ip
#   node = data.aws_instance.master_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].private_ip
# }

# resource "talos_cluster_kubeconfig" "kubeconfig" {
#   client_configuration = talos_machine_secrets.this.client_configuration
#   endpoint                 = data.aws_instance.master_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].public_ip
#   node = data.aws_instance.master_instance_ips[sort(keys(data.aws_instance.master_instance_ips))[0]].private_ip

#   depends_on = [
#     talos_machine_bootstrap.talos_bootstrap
#   ]
# }

# resource "local_file" "kubeconfig" {
#   content  = resource.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
#   filename = "kubeconfig"
# }

# # data "talos_machine_configuration" "worker_group" {
# #   for_each = merge([for info in var.worker_groups : { for index in range(0, var.workers_count) : "${info.name}.${index}" => info }]...)

# #   cluster_name       = var.cluster_name
# #   cluster_endpoint   = "kubeapi.kubecounty.com"
# #   machine_type       = "worker"
# #   machine_secrets    = talos_machine_secrets.this.machine_secrets
# #   kubernetes_version = var.kubernetes_version
# #   talos_version      = var.talos_version
# #   config_patches = concat(
# #     local.config_patches_common,
# #     [yamlencode(local.common_config_patch)],
# #     [yamlencode(local.config_cilium_patch)],
# #     [for path in each.value.config_patch_files : file(path)]
# #   )
# # }

# # resource "talos_machine_configuration_apply" "controlplane" {
# #   count = var.master_count

# #   client_configuration        = talos_machine_secrets.this.client_configuration
# #   machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
# #   endpoint                    = module.talos_control_plane_nodes[count.index].private_ip
# #   node                        = module.talos_control_plane_nodes[count.index].private_ip
# # }

# # resource "talos_machine_configuration_apply" "worker_group" {
# #   for_each = merge([for info in var.worker_groups : { for index in range(0, var.workers_count) : "${info.name}.${index}" => info }]...)

# #   client_configuration        = talos_machine_secrets.this.client_configuration
# #   machine_configuration_input = data.talos_machine_configuration.worker_group[each.key].machine_configuration
# #   endpoint                    = module.talos_worker_group[each.key].public_ip
# #   node                        = module.talos_worker_group[each.key].private_ip
# # }

# # resource "talos_machine_bootstrap" "this" {
# #   depends_on = [talos_machine_configuration_apply.controlplane]

# #   client_configuration = talos_machine_secrets.this.client_configuration
# #   endpoint             = module.talos_control_plane_nodes.0.public_ip
# #   node                 = module.talos_control_plane_nodes.0.private_ip
# # }

