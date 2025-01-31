variable "name" {
  default = "talos_cluster"
}

variable "cidr_block" {
  default = "172.20.0.0/16"
}

variable "bastion_ami" {
  default = "ami-0d64bb532e0502c46"
}

variable "master_count" {
  default = 3
}

variable "master_type" {
  default = "t3.medium"
}

variable "sg_description" {
  default = "This is The Master Node Security Group for my Talos Linux Cluster"
}

variable "wk_sg_description" {
  default = "This is The Worker Node Security Group for my Talos Linux Cluster"
}

variable "talos_version" {
  default     = "v1.9.0"
  description = "Talos version to use for the cluster, if not set, the newest Talos version. Check https://github.com/siderolabs/talos/releases for available releases."
  type        = string
  validation {
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+$", var.talos_version))
    error_message = "The talos_version value must be a valid Talos patch version, starting with 'v'."
  }
}

variable "kubernetes_version" {
  default = "1.32.0"
}

variable "cluster_architecture" {
  default     = "amd64"
  description = "Cluster architecture. Choose 'arm64' or 'amd64'. If you choose 'arm64', ensure to also override the control_plane.instance_type and worker_groups.instance_type with an ARM64-based instance type like 'm7g.large'."
  type        = string
  validation {
    condition     = can(regex("^a(rm|md)64$", var.cluster_architecture))
    error_message = "The cluster_architecture value must be a valid architecture. Allowed values are 'arm64' and 'amd64'."
  }
}

variable "tags" {
  default = {
    "Project" = "Talos Linux"
    "Purpose" = "Homelab"
    "Owner" = "Malchiel Urias"
    "Environment" = "Prod"
  }
}

variable "enable_provisioner" {
  description = "Whether to enable the provisioner for EC2 instance"
  type        = bool
  default     = true
}