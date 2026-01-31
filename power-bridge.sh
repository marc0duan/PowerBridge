#!/bin/bash

# 1. Check Root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# 2. Install Dependencies
echo "Installing dependencies..."
if command -v apt-get &> /dev/null; then
    apt-get update
    apt-get install -y curl socat jq openssl lsof net-tools
elif command -v yum &> /dev/null; then
    yum install -y curl socat jq openssl lsof net-tools
else
    echo "Warning: Unsupported package manager. Trying to proceed..."
fi

# 3. Port 80 Check
echo "Checking Port 80..."
PID=$(lsof -t -i:80)
if [ -n "$PID" ]; then
    echo "Port 80 is occupied by PID $PID. Killing it..."
    kill -9 $PID
fi

# 4. User Input
read -p "Enter your domain name (e.g., service.powerbridge.xyz): " DOMAIN < /dev/tty
if [ -z "$DOMAIN" ]; then
    echo "Domain cannot be empty."
    exit 1
fi

# 5. Install Xray
echo "Installing Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 6. Install acme.sh & Issue Cert
echo "Installing acme.sh..."
curl https://get.acme.sh | sh
source ~/.bashrc

echo "Issuing Certificate for $DOMAIN..."
~/.acme.sh/acme.sh --register-account -m "admin@$DOMAIN"
~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --force

CERT_DIR="/usr/local/etc/xray"
mkdir -p $CERT_DIR
~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
    --fullchain-file $CERT_DIR/fullchain.pem \
    --key-file $CERT_DIR/privkey.pem \
    --reloadcmd "systemctl restart xray"

chmod 644 $CERT_DIR/fullchain.pem
chmod 644 $CERT_DIR/privkey.pem

# 7. Configure Xray
# Generate UUID (simple method if xray uuid cmd fails or just use uuidgen if available, or fallback to kernel)
if command -v xray &> /dev/null; then
    UUID=$(xray uuid)
else
    UUID=$(cat /proc/sys/kernel/random/uuid)
fi

CONFIG_FILE="/usr/local/etc/xray/config.json"

cat > $CONFIG_FILE <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 59999
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "$CERT_DIR/fullchain.pem",
              "keyFile": "$CERT_DIR/privkey.pem"
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 59999,
      "listen": "127.0.0.1",
      "protocol": "dokodemo-door",
      "settings": {
        "address": "www.github.com",
        "port": 80,
        "network": "tcp"
      },
      "tag": "fallback"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

# 8. Service Management
echo "Starting Xray service..."
systemctl enable xray
systemctl restart xray

# 9. Output
echo "=========================================================="
echo "Xray Installed Successfully!"
echo "Domain: $DOMAIN"
echo "UUID: $UUID"
echo "Flow: xtls-rprx-vision"
echo "Network: tcp"
echo "Security: tls"
echo "Port: 443"
echo "=========================================================="
echo "Connection String (VLESS):"
echo "vless://$UUID@$DOMAIN:443?security=tls&encryption=none&flow=xtls-rprx-vision&type=tcp&fp=chrome&sni=$DOMAIN#$DOMAIN"
echo "=========================================================="
