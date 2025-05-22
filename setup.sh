#!/bin/bash
set -euo pipefail

# Prompt for user input
echo "🔐 Fill in the Azure O365 API keys:"
echo ""
read -rp "Enter O365BEAT_TENANT_DOMAIN: " O365BEAT_TENANT_DOMAIN
read -rp "Enter O365BEAT_CLIENT_SECRET: " O365BEAT_CLIENT_SECRET
read -rp "Enter O365BEAT_CLIENT_ID: " O365BEAT_CLIENT_ID
read -rp "Enter O365BEAT_DIRECTORY_ID: " O365BEAT_DIRECTORY_ID

# Confirm inputs
echo ""
echo "🔐 Azure O365 API Keys:"
echo "------------------------"
echo "O365BEAT_TENANT_DOMAIN = $O365BEAT_TENANT_DOMAIN"
echo "O365BEAT_CLIENT_SECRET = $O365BEAT_CLIENT_SECRET"
echo "O365BEAT_CLIENT_ID     = $O365BEAT_CLIENT_ID"
echo "O365BEAT_DIRECTORY_ID  = $O365BEAT_DIRECTORY_ID"
echo ""

read -rp "Do you want to continue with this configuration? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "❌ Installation aborted by user."
    exit 1
fi

# Download and extract o365beat
echo "[+] Downloading o365beat..."
wget -q --show-progress https://prod1-us.blusapphire.net/export/install/beat/o365beat.tar.gz

echo "[+] Extracting o365beat..."
tar -zxf o365beat.tar.gz

echo "[+] Moving o365beat to /opt/o365..."
sudo rm -rf /opt/o365 2>/dev/null || true
sudo mv o365beat /opt/o365
rm -f o365beat.tar.gz

# Write the configuration
CONFIG_FILE="/opt/o365/blucluster.conf"
echo "[+] Writing configuration to $CONFIG_FILE..."
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
# o365beat configuration
O365BEAT_TENANT_DOMAIN="${O365BEAT_TENANT_DOMAIN}"
O365BEAT_CLIENT_SECRET="${O365BEAT_CLIENT_SECRET}"
O365BEAT_CLIENT_ID="${O365BEAT_CLIENT_ID}"
O365BEAT_DIRECTORY_ID="${O365BEAT_DIRECTORY_ID}"
O365BEAT_REGISTRY_PATH="/opt/o365/registry"
EOF

# Install RPM
RPM_FILE=$(find /opt/o365 -name "o365beat-*.rpm" | head -1)
if [[ -z "$RPM_FILE" ]]; then
    echo "❌ Error: RPM package not found in /opt/o365."
    exit 1
fi

echo "[+] Installing o365beat RPM: $RPM_FILE"
sudo rpm -ivh "$RPM_FILE"

# Setup systemd service
SERVICE_FILE="/opt/o365/o365beat.service"
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "❌ Error: o365beat.service file not found in /opt/o365."
    exit 1
fi

echo "[+] Setting up systemd service..."
sudo mv "$SERVICE_FILE" /etc/systemd/system/o365beat.service

echo "[+] Enabling and starting o365beat service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable o365beat.service
sudo systemctl start o365beat.service

# Final message
echo "✅ o365beat installation and setup complete."
echo "📤 Azure O365 logs are being sent on port 12224 🎯"
