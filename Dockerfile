FROM python:3.11-slim-bookworm

ARG APP_DIR=GeminiTranslator

ENV APP_DIR=${APP_DIR}
ENV DISPLAY=:1

# ===== system deps =====
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    procps \
    x11vnc \
    supervisor \
    xserver-xorg-core \
    xserver-xorg-video-dummy \
    x11-utils \
    fluxbox \
    dbus-x11 \
    wget \
    fonts-dejavu-core \
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-noto-color-emoji \
    locales \
    libgl1 \
    libglib2.0-0 \
    libxkbcommon-x11-0 \
    libxcb-cursor0 \
    libxcb-xinerama0 \
    libxcb-icccm4 \
    libxcb-keysyms1 \
    libxcb-image0 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xkb1 \
    libegl1 \
    mesa-utils \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/* \
    && echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen ru_RU.UTF-8

# ===== VNC password =====
RUN mkdir -p /var/run/supervisor /var/log/supervisor
COPY entrypoint.sh /app/${APP_DIR}/entrypoint.sh
RUN chmod +x /app/${APP_DIR}/entrypoint.sh

# ===== app =====
COPY ${APP_DIR}/ /app/${APP_DIR}/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY 10-dummy.conf /etc/X11/xorg.conf.d/
COPY ${APP_DIR}/requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir -r /tmp/requirements.txt

WORKDIR /app/${APP_DIR}

 

ENTRYPOINT ["/app/GeminiTranslator/entrypoint.sh"]
