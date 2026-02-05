#!/bin/bash
# Dashy Dashboard LXC Setup Script for Proxmox
# Repository: https://github.com/Igneasz/proxmox-dashy

set -e

echo "=================================================="
echo "  Dashy Dashboard LXC Deployment"
echo "  Target IP: 10.216.1.220"
echo "  Node: pve03"
echo "=================================================="
echo ""

# Configuration
CTID=220
HOSTNAME="dashy"
PASSWORD="changeme123"
DISK_SIZE="8"
MEMORY=1024
CORES=1
STORAGE="local-lvm"
TEMPLATE="local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
IP_ADDRESS="10.216.1.220/24"
GATEWAY="10.216.1.1"

echo "[1/6] Checking if container ID $CTID already exists..."
if pct status $CTID &>/dev/null; then
    echo "ERROR: Container $CTID already exists!"
    echo "Please remove it first: pct destroy $CTID"
    exit 1
fi

echo "[2/6] Creating LXC container..."
pct create $CTID $TEMPLATE \
    --hostname $HOSTNAME \
    --password $PASSWORD \
    --cores $CORES \
    --memory $MEMORY \
    --rootfs $STORAGE:$DISK_SIZE \
    --net0 name=eth0,bridge=vmbr0,ip=$IP_ADDRESS,gw=$GATEWAY \
    --features nesting=1 \
    --unprivileged 1 \
    --onboot 1
echo "[3/6] Starting container..."
pct start $CTID
sleep 5
echo "[4/6] Installing Docker and dependencies..."
pct exec $CTID -- bash -c "
    apt-get update
    apt-get install -y curl ca-certificates gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \"deb [arch=\[0m\[32m$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(. /etc/os-release && echo \$VERSION_CODENAME) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
"
echo "[5/6] Creating Dashy configuration..."
pct exec $CTID -- bash -c "
    mkdir -p /opt/dashy
    cat > /opt/dashy/conf.yml << 'EOF'
pagInfo:
  title: Proxmox Dashboard
  description: My Homelab Dashboard
  navLinks:
    - title: GitHub
      path: https://github.com/Igneasz/proxmox-dashy
  
appConfig:
  theme: nord-frost
  statusCheck: true
  
sections:
  - name: Proxmox Cluster
    icon: fas fa-server
    items:
      - title: Proxmox pve03
        description: Proxmox VE Management
        url: https://10.216.1.203:8006
        icon: https://www.proxmox.com/images/proxmox/Proxmox_logo_standard_hex_400px.png
        
  - name: Monitoring
    icon: fas fa-chart-line
    items:
      - title: Dashy GitHub
        description: Project Repository
        url: https://github.com/Igneasz/proxmox-dashy
        icon: fab fa-github
EOF

    cat > /opt/dashy/docker-compose.yml << 'EOF'
version: '3.8'

services:
  dashy:
    image: lissy93/dashy:latest
    container_name: dashy
    ports:
      - 8080:8080
    volumes:
      - ./conf.yml:/app/user-data/conf.yml
    environment:
      - NODE_ENV=production
    restart: unless-stopped
EOF
"
echo "[6/6] Starting Dashy..."
pct exec $CTID -- bash -c "
    cd /opt/dashy
    docker compose up -d
"
echo ""
echo "=================================================="
echo "  ✅ Installation Complete!"
echo "=================================================="
echo ""
echo "Dashy Dashboard: http://10.216.1.220:8080"
echo "Container ID: $CTID"
echo "Hostname: $HOSTNAME"
echo "Root Password: $PASSWORD (CHANGE THIS!)"
echo ""
echo "Commands:"
echo "  - Access shell: pct enter $CTID"
echo "  - Stop container: pct stop $CTID"
echo "  - Start container: pct start $CTID"
echo ""
