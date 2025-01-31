#!/bin/bash
# Update system and install Docker
# sudo apt-get update -y
# sudo apt-get install -y docker.io

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce
sudo usermod -aG docker ubuntu  # Add default user to the Docker group

# # Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Install talosctl
curl -sL https://talos.dev/install | sh

# Create Traefik configuration directory
mkdir -p /etc/traefik

# Traefik static configuration
cat <<EOT >> /etc/traefik/traefik.yml
entryPoints:
  web:
    address: ":80"

providers:
  file:
    directory: "/etc/traefik/dynamic"

api:
  dashboard: true
EOT

# Traefik dynamic configuration
mkdir -p /etc/traefik/dynamic
cat <<EOT >> /etc/traefik/dynamic/config.yml
http:
  routers:
    api-server:
      rule: "Host(\`kubeapi.kubecounty.com\`)"
      service: api-server

  services:
    api-server:
      loadBalancer:
        servers:
          - url: "https://${CONTROLLER_1}:6443"
          - url: "https://${CONTROLLER_2}:6443"
          - url: "https://${CONTROLLER_3}:6443"
EOT

# Run Traefik container
sudo docker run -d \
  --name=traefik \
  --env-file /tmp/traefik.env \
  -p 80:80 \
  -v /etc/traefik/traefik.yml:/traefik.yml \
  -v /etc/traefik/dynamic:/etc/traefik/dynamic \
  -v /var/run/docker.sock:/var/run/docker.sock \
  traefik:v3.2.3
