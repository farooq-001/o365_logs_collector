#!/bin/bash

# Check if docker is installed
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is NOT installed."
  exit 1
else
  echo "Docker is installed."
fi

# Check if docker-compose is installed
if ! command -v docker-compose >/dev/null 2>&1; then
  echo "docker-compose is NOT installed."
  exit 1
else
  echo "docker-compose is installed."
fi

# Read API info from user
read -rp "Enter ORG-ID (client_id): " ORG_ID
read -rp "Enter APPLICATION-ID: " APPLICATION_ID
read -rp "Enter TENANT-ID: " TENANT_ID
read -rp "Enter CLIENT-SECRETE: " CLIENT_SECRETE

# Create directories
mkdir -p /opt/docker/filebeat/config /opt/docker/filebeat/o365beat/registry /opt/docker/sample-logs 

# Write the filebeat config YAML with user inputs
cat > /opt/docker/filebeat/config/o365_filebeat.yaml <<EOF
###################### Netflow-ipfix Configuration #########################
filebeat.inputs:
  - type: o365audit
    enabled: true
    fields:
      log.type: o365_audit
      client_id: ${ORG_ID}
    fields_under_root: true
    application_id: ${APPLICATION_ID}
    tenant_id:  ${TENANT_ID}
    client_secret: ${CLIENT_SECRETE}
    content_type:
      - Audit.AzureActiveDirectory
      - Audit.Exchange
      - Audit.SharePoint
      - Audit.General
      - DLP.All

#====================== Filebeat Global Options ===============================
filebeat.registry.path: /opt/docker/filebeat/o365beat/registry/azure_o365beat

#============================= Filebeat Modules ===============================
filebeat.config.modules:
  path: "\${path.config}/modules.d/*.yml"
  reload.enabled: true
  reload.period: 60s

#============================= Processors =====================================
processors:
  - add_tags:
      tags: ["forwarded"]
  - add_host_metadata:
      when.not.contains.tags: forwarded

#----------------------------- Logstash Output --------------------------------
output.logstash:
  bulk_max_size: 8192
  hosts: ["127.0.0.1:12224"]
  timeout: 120s
  loadbalance: true
  worker: 7

#--------------------------- Seccomp Settings (Optional) -----------------------
seccomp:
  default_action: allow
  syscalls:
    - action: allow
      names:
        - rseq

#----------------------------- File Output (Commented) -------------------------
#output.file:
#  enabled: true
#  path: "/opt/docker/sample-logs"
#  filename: "o365.log"
#  rotate_every_kb: 10000    # Rotate file after 10 MB
#  number_of_files: 7  

EOF

# Write the docker-compose.yml
cat > /opt/docker/filebeat/o365beat/docker-compose.yml <<EOF
version: '3.8'

services:
  ####### azure-o365 ######
  o365_filebeat:
    image: docker.elastic.co/beats/filebeat:7.17.27
    container_name: o365beat
    network_mode: host
    volumes:
      - /opt/docker/filebeat/config/o365_filebeat.yaml:/usr/share/filebeat/filebeat.yml
      - /opt/docker/filebeat/o365beat/registry:/opt/docker/filebeat/o365beat/registry
    # - /opt/docker/sample-logs:/opt/docker/sample-logs  # Enable if need file output
    environment:
      - BEAT_PATH=/usr/share/filebeat
    user: root
    restart: always

EOF

# Prompt user for installation
read -rp "Do you want to install (start) the docker-compose stack? (y/n): " yn
case "$yn" in
  [Yy]* )
    echo "Starting docker-compose stack..."
    docker-compose -f /opt/docker/filebeat/o365beat/docker-compose.yml up -d
    echo "Docker-compose stack started."
    ;;
  * )
    echo "Exiting without installation."
    exit 0
    ;;
esac
