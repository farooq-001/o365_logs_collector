#!/bin/bash
set -e  # Exit on any error

echo "[+] Downloading o365beat..."
wget -q --show-progress https://prod1-us.blusapphire.net/export/install/beat/o365beat.tar.gz

echo "[+] Extracting o365beat..."
tar -zxvf o365beat.tar.gz

echo "[+] Moving o365beat to /opt/o365..."
mv o365beat /opt/o365
rm -rf o365beat.tar.gz

echo "🔐 Fill the azure-o365-API Keys:"
echo ""
read -rp "Enter O365BEAT_TENANT_DOMAIN: " O365BEAT_TENANT_DOMAIN
read -rp "Enter O365BEAT_CLIENT_SECRET: " O365BEAT_CLIENT_SECRET
read -rp "Enter O365BEAT_CLIENT_ID: " O365BEAT_CLIENT_ID
read -rp "Enter O365BEAT_DIRECTORY_ID: " O365BEAT_DIRECTORY_ID

# Confirm before continuing
echo ""
echo "🔐 azure-o365-API Keys"
echo "----------------------"
echo "O365BEAT_TENANT_DOMAIN = $O365BEAT_TENANT_DOMAIN"
echo "O365BEAT_CLIENT_SECRET = $O365BEAT_CLIENT_SECRET"
echo "O365BEAT_CLIENT_ID     = $O365BEAT_CLIENT_ID"
echo "O365BEAT_DIRECTORY_ID  = $O365BEAT_DIRECTORY_ID"
echo ""

read -rp "Do you want to continue with this configuration? (y/n): " CONFIRM
if [[ "$CONFIRM" != [yY] ]]; then
    echo "Installation aborted."
    exit 1
fi

# Write configuration file
echo "[+] Writing configuration to /opt/o365/blucluster.conf..."
tee /opt/o365/blucluster.conf > /dev/null <<EOF
# o365 config

O365BEAT_TENANT_DOMAIN="${O365BEAT_TENANT_DOMAIN}"
O365BEAT_CLIENT_SECRET="${O365BEAT_CLIENT_SECRET}"
O365BEAT_CLIENT_ID="${O365BEAT_CLIENT_ID}"
O365BEAT_DIRECTORY_ID="${O365BEAT_DIRECTORY_ID}"
O365BEAT_REGISTRY_PATH="/opt/o365/registry"
EOF

# Install RPM
RPM_FILE=$(find /opt/o365 -name "o365beat-*.rpm" | head -1)
if [[ -z "$RPM_FILE" ]]; then
    echo "[!] Error: RPM package not found in /opt/o365."
    exit 1
fi

echo "[+] Installing o365beat RPM..."
sudo rpm -ivh "$RPM_FILE"

# Setup systemd service
SERVICE_FILE="/opt/o365/o365beat.service"
if [ ! -f "$SERVICE_FILE" ]; then
    echo "[!] Error: o365beat.service file not found in /opt/o365."
    exit 1
fi

echo "[+] Setting up systemd service..."
mv "$SERVICE_FILE" /etc/systemd/system/o365beat.service

# Start and enable the service
echo "[+] Starting o365beat service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable o365beat.service
systemctl start o365beat.service

echo "✅ o365beat installation and setup complete..."
echo ""
echo "azure-o365 logs output port..12224🎯"
