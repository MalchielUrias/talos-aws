# Output private and public IPs
output "master_private_ips" {
  value = [for inst in data.aws_instance.master_instance_ips : inst.private_ip]
}

output "master_public_ips" {
  value = [for inst in data.aws_instance.master_instance_ips : inst.public_ip]
}

output "worker_private_ips" {
  value = [for inst in data.aws_instance.worker_instance_ips : inst.private_ip]
}

output "worker_public_ips" {
  value = [for inst in data.aws_instance.worker_instance_ips : inst.public_ip]
}

# output "traefik_ip" {
#   value = module.traefik.public_ip
# }