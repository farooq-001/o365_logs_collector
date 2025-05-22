#!/bin/bash
# uninstall_o365beat.sh

echo "[!] This will stop and remove o365beat, including configuration files."

read -p "Are you sure you want to proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Uninstallation aborted."
    exit 1
fi

# Stop and disable the service
echo "[+] Stopping o365beat service..."
sudo systemctl stop o365beat.service
sudo systemctl disable o365beat.service

# Remove systemd service file
echo "[+] Removing systemd service file..."
sudo rm -f /etc/systemd/system/o365beat.service

# Reload systemd
echo "[+] Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

# Remove installed files
echo "[+] Removing /opt/o365 directory..."
sudo rm -rf /opt/o365

# Remove RPM package
echo "[+] Removing o365beat RPM package..."
sudo rpm -e o365beat

echo "[✓] o365beat has been uninstalled successfully."
