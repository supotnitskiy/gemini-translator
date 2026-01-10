#!/usr/bin/env bash
set -e

VNC_PASS_FILE="/root/.vnc/passwd"

mkdir -p /root/.vnc

if [ -z "$VNC_PASSWORD" ]; then
  echo "ERROR: VNC_PASSWORD is not set"
  exit 1
fi

# Всегда пересоздаём файл пароля
x11vnc -storepasswd "$VNC_PASSWORD" "$VNC_PASS_FILE"

chmod 600 "$VNC_PASS_FILE"

echo "VNC password file created"

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf