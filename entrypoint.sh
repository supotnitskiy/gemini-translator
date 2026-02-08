#!/usr/bin/env bash
set -e

VNC_PASS_FILE="/root/.vnc/passwd"

mkdir -p /root/.vnc

if [ -z "$VNC_PASSWORD" ]; then
  echo "ERROR: VNC_PASSWORD is not set"
  exit 1
fi

# Разрешение экрана из переменной окружения (по умолчанию 1280x720 — меньше трафика и задержка в VNC)
DISPLAY_RESOLUTION="${DISPLAY_RESOLUTION:-1280x720}"
echo "Using display resolution: $DISPLAY_RESOLUTION"

# Генерируем конфиг X с выбранным разрешением
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-dummy.conf << EOF
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
    VideoRam    256000
EndSection

Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
EndSection

Section "Screen"
    Identifier "DummyScreen"
    Device     "DummyDevice"
    Monitor    "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "$DISPLAY_RESOLUTION"
    EndSubSection
EndSection

Section "ServerLayout"
    Identifier "DummyLayout"
    Screen     "DummyScreen"
EndSection
EOF

# Всегда пересоздаём файл пароля
x11vnc -storepasswd "$VNC_PASSWORD" "$VNC_PASS_FILE"

chmod 600 "$VNC_PASS_FILE"

echo "VNC password file created"

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf