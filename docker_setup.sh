vi /opt/docker/o365/docker-compose.yml
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




vi /opt/docker/o365/o365audit.yaml

##################### Filebeat Configuration - OneLogin #########################

#======================= Filebeat Inputs =============================
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
#================== Filebeat Global Options ===============================
filebeat.registry.path: /opt/docker/o365/registry/o365

#========================= Filebeat Modules ===============================
  path: ${path.config}/modules.d/*.yml
  reload.enabled: false
processors:
- add_tags:
    tags: ["forwarded"]
- add_host_metadata:
    when.not.contains.tags: forwarded

#========================= Logstash Output ===============================
output.file:
  enabled: true
  path: "/opt/docker/o365"
  filename: "test.log"
  rotate_every_kb: 10000    # Rotate file after 10 MB
  number_of_files: 7  

#output.logstash:
#  hosts:
#  - 127.0.0.1:12224

#============================= Settings ============================
seccomp:
  default_action: allow
  syscalls:
    - action: allow
      names:
        - rseq
