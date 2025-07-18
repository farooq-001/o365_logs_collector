#!/bin/bash

echo "🔐 FILL THE ONELOGIN-API KEYS:"

# Prompt for required values
read -p "Enter APPLICATION_ID: " APPLICATION_ID
read -p "Enter TENANT_ID: " TENANT_ID
read -p "Enter CLIENT_SECRET: " CLIENT_SECRET

# Display inputs
echo ""
echo "🔐 You Have Entered The Following ONELOGIN-API Keys:"
echo "APPLICATION_ID : $APPLICATION_ID"
echo "TENANT_ID      : $TENANT_ID"
echo "CLIENT_SECRET  : $CLIENT_SECRET"
echo ""

# Confirm installation
read -p "Proceed with installation? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ Installation cancelled."
    exit 1
fi

# Create required directories
mkdir -p /opt/docker/o365/registry

# Write Docker Compose file
cat <<EOF > /opt/docker/o365/docker-compose.yml
version: '3.7'

services:
  o365audit:
    image: docker.elastic.co/beats/filebeat:7.17.29
    container_name: o365audit
    network_mode: host
    volumes:
      - /opt/docker:/opt/docker
      - /opt/docker/o365/o365audit.yaml:/usr/share/filebeat/filebeat.yml
      - /opt/docker/o365/registry:/opt/docker/o365/registry
    environment:
      - BEAT_PATH=/usr/share/filebeat
    user: root
    restart: always
EOF

# Write Filebeat configuration
cat <<EOF > /opt/docker/o365/o365audit.yaml
##################### Filebeat Configuration - O365 Audit #########################

filebeat.inputs:
- type: o365audit
  enabled: true
  fields:
    log.type: o365_audit
  fields_under_root: true
  application_id: ${APPLICATION_ID}
  tenant_id: ${TENANT_ID}
  client_secret: ${CLIENT_SECRET}
  content_type:
    - Audit.AzureActiveDirectory
    - Audit.Exchange
    - Audit.SharePoint
    - Audit.General
    - DLP.All

filebeat.registry.path: /opt/docker/o365/registry/o365

processors:
- add_tags:
    tags: ["forwarded"]
- add_host_metadata:
    when.not.contains.tags: forwarded

output.file:
  enabled: true
  path: "/opt/docker/o365"
  filename: "test.log"
  rotate_every_kb: 10000
  number_of_files: 7

#output.logstash:
#  hosts:
#    - 127.0.0.1:12224

seccomp:
  default_action: allow
  syscalls:
    - action: allow
      names:
        - rseq
EOF

echo "✅ Configuration completed. You can now start the container using:"
echo "   sudo docker-compose -f /opt/docker/o365/docker-compose.yml up -d"
