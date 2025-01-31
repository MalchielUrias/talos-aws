# ======= Data Sources =======
data "aws_ami" "talos" {
  owners      = ["540036508848"] # Sidero Labs
  most_recent = true
  name_regex  = "^talos-${var.talos_version}-.*-${var.cluster_architecture}$"

  filter {
    name   = "architecture"
    values = [local.instance_architecture]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}


# ========== Locals =============
locals {

  instance_architecture    = var.cluster_architecture == "amd64" ? "x86_64" : var.cluster_architecture
}

# ======= Infra Setup ========

# Network 
module "talos_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.name}-vpc"
  cidr = var.cidr_block

  azs             = [ data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2] ]
  private_subnets = [ cidrsubnet(var.cidr_block, 8, 0), cidrsubnet(var.cidr_block, 8, 1), cidrsubnet(var.cidr_block, 8, 2) ]
  public_subnets  = [ cidrsubnet(var.cidr_block, 8, 3), cidrsubnet(var.cidr_block, 8, 4), cidrsubnet(var.cidr_block, 8, 5) ]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  map_public_ip_on_launch = true

  enable_ipv6                                   = false
  public_subnet_assign_ipv6_address_on_creation = false

  public_subnet_ipv6_prefixes   = [0, 1, 2]
  private_subnet_ipv6_prefixes  = [3, 4, 5]

  tags                 = var.tags
}

module "alb_sg" {
  source      = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/sg"
  name        = "${var.name}-alb-sg"
  description = var.sg_description
  tags        = var.tags
  vpc_id      = module.talos_vpc.vpc_id
  rules = [
    {
      "type"        = "ingress"
      "description" = "HTTP"
      "from_port"   = 80,
      "to_port"     = 80,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "ingress"
      "description" = "Talos"
      "from_port"   = 50000,
      "to_port"     = 50001,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "ingress"
      "from_port"   = 22,
      "to_port"     = 22,
      "protocol"    = "tcp",
      "cidr_blocks" = [ "0.0.0.0/0" ]
    },
    {
      "type"        = "ingress"
      "description" = "HTTP"
      "from_port"   = 443,
      "to_port"     = 443,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "ingress"
      "description" = "Kube API"
      "from_port"   = 6443,
      "to_port"     = 6443,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "egress"
      "from_port"   = 0,
      "to_port"     = 0,
      "protocol"    = "-1",
      "cidr_blocks" = ["0.0.0.0/0"]
    }
  ]
}

# ALB for Talos
module "alb_setup" {
  source = "./modules/alb"

  name = "talos-alb"
  vpc_id = module.talos_vpc.vpc_id
  subnets = module.talos_vpc.public_subnets 
  
}

# TalosConfig
module "talos_config" {
  source             = "./talos/configuration"
  project_name       = var.name
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  load_balancer_dns  = module.alb_setup.alb_dns_name

  providers = {
    talos = talos
  }
}

# Keypair
module "talos_keypair" {
  source   = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/keypair"
  key_name = "talos_keypair"
}

# Computer - Master Node
module "talos_master" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/asg"
  name = "talos_masters"
  instance_type = "t3.medium"
  ami_id = data.aws_ami.talos.id
  associate_public_ip = true
  security_group_ids = [ module.talos_master_sg.sg_id ]
  max_size = 5
  min_size = 1
  desired_capacity = 1
  vpc_zone_identifier = module.talos_vpc.public_subnets
  on_demand_percentage_above_base_capacity = 25
  spot_instance_pools = 2
  host_types = [ "t3.medium", "t3.xlarge" ]
  key_name = module.talos_keypair.key_name
  user_data = base64encode(module.talos_config.control_plane_machine_config)
}

# Attach Masters to ALB TG
resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = module.talos_master.name
  lb_target_group_arn    = module.alb_setup.tg_arn
}


# Master Node Security Group
module "talos_master_sg" {
  source      = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/sg"
  name        = "${var.name}-master-sg"
  description = var.sg_description
  tags        = var.tags
  vpc_id      = module.talos_vpc.vpc_id
  rules = [
    {
      "type"        = "ingress"
      "from_port"   = 22,
      "to_port"     = 22,
      "protocol"    = "tcp",
      "cidr_blocks" = [ "0.0.0.0/0" ]
    },
    {
      "type"        = "ingress"
      "description" = "Talos API"
      "from_port"   = 50000,
      "to_port"     = 50001,
      "protocol"    = "tcp",
      "cidr_blocks" = [ "0.0.0.0/0" ]
    },
    {
      "type"        = "ingress"
      "description" = "Kubernetes API Server"
      "from_port"   = 6443,
      "to_port"     = 6443,
      "protocol"    = "tcp",
      "cidr_blocks" = [ "0.0.0.0/0" ]
    },
    {
      "type"        = "ingress"
      "description" = "Kubernetes API Server"
      "from_port"   = 443,
      "to_port"     = 443,
      "protocol"    = "tcp",
      "cidr_blocks" = [ "0.0.0.0/0" ]
    },
    {
      "type"        = "egress"
      "from_port"   = 0,
      "to_port"     = 0,
      "protocol"    = "-1",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
  ]
}


# Computer - Worker Node
module "talos_workers" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/asg"
  name = "talos_workers"
  instance_type = "t3.medium"
  ami_id = data.aws_ami.talos.id
  associate_public_ip = false
  security_group_ids = [ module.talos_worker_sg.sg_id ]
  max_size = 10
  min_size = 1
  desired_capacity = 2
  vpc_zone_identifier = module.talos_vpc.private_subnets
  on_demand_percentage_above_base_capacity = 25
  spot_instance_pools = 2
  host_types = [ "t3.medium", "t3.xlarge" ]
  key_name = module.talos_keypair.key_name
  user_data = base64encode(module.talos_config.worker_machine_config)
}


# Worker Node Security Group
module "talos_worker_sg" {
  source      = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/sg"
  name        = "${var.name}-worker-sg"
  description = var.wk_sg_description
  tags        = var.tags
  vpc_id      = module.talos_vpc.vpc_id
  rules = [
    {
      "type"        = "ingress"
      "from_port"   = 22,
      "to_port"     = 22,
      "protocol"    = "tcp",
      "cidr_blocks" = [ var.cidr_block ]
    },
    {
      "type"        = "ingress"
      "from_port"   = 80,
      "to_port"     = 80,
      "protocol"    = "tcp",
      "cidr_blocks" = [ var.cidr_block ]
    },
    {
      "type"        = "ingress"
      "from_port"   = 443,
      "to_port"     = 443,
      "protocol"    = "tcp",
      "cidr_blocks" = [ var.cidr_block ]
    },
    {
      "type"        = "ingress"
      "description" = "Talos API"
      "from_port"   = 50000,
      "to_port"     = 50001,
      "protocol"    = "tcp",
      "cidr_blocks" = [ var.cidr_block ]
    },
    {
      "type"        = "ingress"
      "description" = "Kubernetes API Server"
      "from_port"   = 6443,
      "to_port"     = 6443,
      "protocol"    = "tcp",
      "cidr_blocks" = [ var.cidr_block ]
    },
    {
      "type"        = "egress"
      "from_port"   = 0,
      "to_port"     = 0,
      "protocol"    = "-1",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
  ]
}

# Get Ips - Master ASG

data "aws_instances" "control_plane_instances" {
  depends_on = [
    module.talos_master
  ]
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [module.talos_master.name]
  }
}

# Fetch the instance IDs of nodes in the ASG
data "aws_autoscaling_group" "master_asg" {
  name = module.talos_master.name

  depends_on = [ module.talos_master ]
}

# Fetch instance details
data "aws_instances" "master_instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = data.aws_autoscaling_group.master_asg.name
  }
}

# Fetch IPs for instances
data "aws_instance" "master_instance_ips" {
  for_each = toset(data.aws_instances.master_instances.ids)
  instance_id = each.key
}

# Get Ips - Worker ASG

# Fetch the instance IDs of nodes in the ASG
data "aws_autoscaling_group" "worker_asg" {
  name = module.talos_workers.name

  depends_on = [ module.talos_workers ]
}

# Fetch instance details
data "aws_instances" "worker_instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = data.aws_autoscaling_group.worker_asg.name
  }
}

# Fetch IPs for instances
data "aws_instance" "worker_instance_ips" {
  for_each = toset(data.aws_instances.worker_instances.ids)
  instance_id = each.key
}


# Create a local file with the private IPs of the master instances
resource "local_file" "env_file" {
  filename = "traefik.env"

  content = join("\n", [
    for index, instance in sort(keys(data.aws_instance.master_instance_ips)) :
    "CONTROLLER_${index + 1}=${data.aws_instance.master_instance_ips[instance].private_ip}"
  ])
}

module "talos_bootstrap" {
  source               = "./talos/bootstrap"
  client_configuration = module.talos_config.client_configuration
  public_ip            = data.aws_instances.control_plane_instances.public_ips[0]
  private_ip           = data.aws_instances.control_plane_instances.private_ips[0]

  providers = {
    talos = talos
  }
}