#!/bin/bash

# Root privilege check
if [ "$EUID" -ne 0 ]; then
    echo -e "\n❌ Invalid User! Please login as root and rerun the script.\n"
    exit 1
fi

echo -e "\n🔐 FILL THE O365 Audit-API KEYS:\n"

# Prompt for required values
read -p "Enter APPLICATION_ID: " APPLICATION_ID
read -p "Enter TENANT_ID: " TENANT_ID
read -s -p "Enter CLIENT_SECRET: " CLIENT_SECRET
echo ""

# Display inputs (mask CLIENT_SECRET)
echo -e "\n🔐 You Have Entered The Following O365 Audit-API Keys:"
echo "APPLICATION_ID : $APPLICATION_ID"
echo "TENANT_ID      : $TENANT_ID"
echo "CLIENT_SECRET  : $CLIENT_SECRET"
echo ""

# Confirm installation
read -p "Proceed with installation? (y/n): " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "❌ Installation cancelled."
    exit 1
fi

# Install Docker if missing
if ! command -v docker &>/dev/null || ! (command -v docker-compose &>/dev/null || docker compose version &>/dev/null); then
    read -p "Docker and/or Docker Compose not found. Install now? (y/n): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        curl -k -sS https://prod1-us.blusapphire.net/export/install/scripts/install-docker.sh | bash -
    else
        echo "❌ Docker is required. Aborting."
        exit 1
    fi
else
    echo "✅ Docker and Docker Compose are already installed."
fi

# Create required directories
mkdir -p /opt/docker/o365/log

# Create Docker Compose file
cat <<EOF > /opt/docker/o365/docker-compose.yml
version: '3.7'

services:
  o365audit:
    image: docker.elastic.co/beats/filebeat:7.17.29
    container_name: o365audit
    network_mode: host
    volumes:
      - /opt/docker/o365/log:/opt/docker/o365/log
      - /opt/docker/o365/o365audit.yaml:/usr/share/filebeat/filebeat.yml
      - /opt/docker/o365/registry:/opt/docker/o365/registry
    environment:
      - BEAT_PATH=/usr/share/filebeat
    user: root
    restart: always
EOF
# Create Filebeat config file with properly quoted secrets and entered values as comments
cat <<EOF > /opt/docker/o365/o365audit.yaml
########################################################################
#            Filebeat Configuration - O365 Audit 
########################################################################
# 🔐 Entered O365 Audit-API Keys:
# APPLICATION_ID : $APPLICATION_ID
# TENANT_ID      : $TENANT_ID
# CLIENT_SECRET  : $CLIENT_SECRET


filebeat.inputs:
- type: o365audit
  enabled: true
  fields:
    log.type: o365_audit
  fields_under_root: true
  application_id: "$APPLICATION_ID"
  tenant_id: "$TENANT_ID"
  client_secret: "$CLIENT_SECRET"
  content_type:
    - Audit.AzureActiveDirectory
    - Audit.Exchange
    - Audit.SharePoint
    - Audit.General
    - DLP.All

#================== Filebeat Global Options ===============================
filebeat.registry.path: /opt/docker/o365/registry/o365

#========================= Filebeat Modules ===============================
filebeat.config.modules:
  path: "\${path.config}/modules.d/*.yml"
  reload.enabled: true
  reload.period: 60s

processors:
- add_tags:
    tags: ["forwarded"]
- add_host_metadata:
    when.not.contains.tags: forwarded

#========================= Output ===============================
output.logstash:
  hosts: ["127.0.0.1:12224"]
  loadbalance: true
  worker: 5
  bulk_max_size: 8192

#============================= Security Settings ============================
seccomp:
  default_action: allow
  syscalls:
    - action: allow
      names:
        - rseq
EOF

# Secure the config file
chmod 600 /opt/docker/o365/o365audit.yaml

# Final Message
echo -e "\n✅ Configuration completed successfully."
echo -e "🚀 You can now start the container using:\n"
echo "   sudo docker compose -f /opt/docker/o365/docker-compose.yml up -d"
