#!/bin/bash
set -euo pipefail

# إنشاء جلسة tmux جديدة
tmux new -d -s singbox_srv

# إنشاء مجلد العمل
mkdir -p sing
cd sing

# توليد شهادة TLS
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=ea.com"

# تحميل وفك ضغط sing-box
wget -q https://github.com/SagerNet/sing-box/releases/download/v1.12.10/sing-box-1.12.10-linux-amd64.tar.gz
tar -xzf sing-box-1.12.10-linux-amd64.tar.gz

# إيجاد ملف التشغيل
SINGBOX_BIN=$(find . -maxdepth 2 -type f -name 'sing-box' -print -quit)
if [ -z "$SINGBOX_BIN" ]; then
  echo "❌ sing-box not found"
  exit 1
fi
chmod +x "$SINGBOX_BIN"

# إنشاء ملف الإعداد config.json
cat <<'EOF' > config.json
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": 6666,
      "users": [
        {
          "uuid": "7c6de543-881b-4582-8017-9e1fe8c90d64"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "cert.pem",
        "key_path": "key.pem",
        "alpn": ["http/1.1"]
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    }
  ]
}
EOF

# تشغيل sing-box في الخلفية
"$SINGBOX_BIN" run -c config.json &

# استخراج IP العام للسيرفر
SERVER_IP=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me || echo "0.0.0.0")

# إنشاء رابط vless تلقائي
UUID="7c6de543-881b-4582-8017-9e1fe8c90d64"
PORT=6666
DOMAIN="ea.com"
ALPN="http/1.1"
LABEL="ahmed-kh-new update"

VLESS_URL="vless://${UUID}@${SERVER_IP}:${PORT}?encryption=none&flow=none&type=tcp&headerType=none&security=tls&sni=${DOMAIN}&alpn=${ALPN//\//%2F}#${LABEL}"

echo ""
echo "✅ sing-box setup complete!"
echo ""
echo "👇 VLESS client config (copy and use):"
echo "$VLESS_URL"
echo ""
